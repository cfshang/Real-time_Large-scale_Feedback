#include "function.h"

using namespace std;

#define BLOCK_NUM_ISHIFT 256
#define THREAD_NUM_ISHIFT 256
#define OPENMP_THREAD_NUM 12
__global__ void getwarpdata_kernel(float *data,float *warpdata,int width,int *index,int warpSize,int warpDataLen,int warpNum){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	// int length = width * height;
	//   int threadIndex = bid *BLOCK_NUM_SHIFT + tid;
	int offset = blockDim.x*gridDim.x;
	/*int srcstart = index[bid];
	  int deststart = bid * warpDataLen;

	  for(int i=0; i< warpSize;i++){
	  int destIndex = deststart+tid*warpSize+i;
	  int srcIndex  = srcstart+tid*width+i;
	  warpdata[destIndex] = data[srcIndex];
	  }*/
	int srcstart;
	int deststart;
	int destindex;
	int srcindex;
	for(int i=0;i <warpNum;i++){
		srcstart = index[i];
		deststart = i * warpDataLen;
		destindex = deststart + bid * warpSize + tid;
		srcindex = srcstart + bid *width + tid;
		warpdata[destindex] = data[srcindex];
	}
}
__global__ void cuifftshift(float *src,float *out,int width,int height){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	//size_t size = width * height;
	size_t xshift = width / 2;
	if(width % 2 != 0)
		xshift ++ ;
	size_t yshift = height / 2;
	if(height % 2 != 0)
		yshift ++;
	size_t size = width * height;
	int threadIndex = bid *blockDim.x + tid;
	int offset = blockDim.x*gridDim.x;
	for(int i=threadIndex; i< size; i+= offset){
		size_t yIdx = i / width;
		size_t xIdx = i % width;
		size_t outY = (yIdx + yshift) % height;
		size_t outX = (xIdx + xshift) % width;
		size_t outIdx = outX + width*outY;
		out[outIdx] = src[i];
	}

}
__global__ void cuifftshift1(float *src,float *out,int width,int height,int warpNum, int warpdataLen){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	//size_t size = width * height;
	size_t xshift = width / 2;
	if(width % 2 != 0)
		xshift ++ ;
	size_t yshift = height / 2;
	if(height % 2 != 0)
		yshift ++;
	size_t size = width * height;
	int threadIndex = bid *blockDim.x + tid;
	int offset = blockDim.x*gridDim.x;
	for(int j = 0; j < warpNum; j ++){
		int index = j * warpdataLen;
		for(int i=threadIndex; i< size; i+= offset){
			size_t yIdx = i / width;
			size_t xIdx = i % width;
			size_t outY = (yIdx + yshift) % height;
			size_t outX = (xIdx + xshift) % width;
			size_t outIdx = outX + width*outY;
			out[outIdx] = src[i];
		}
		__threadfence();
		__syncthreads();
	}

}
__global__ void cuComplexMulti(Complex *src1,Complex *src2,Complex *out,int warpNum,int warpdatalen){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	int threadIndex = bid *blockDim.x + tid;
	int offset = blockDim.x*gridDim.x;
	int size = warpNum * warpdatalen;
	for(int i=threadIndex; i< size; i+= offset){
		out[i].x=(src1[i].x*src2[i].x - src1[i].y*src2[i].y);
		out[i].y=(src1[i].x*src2[i].y + src1[i].y*src2[i].x);
	}
	/*int index = bid * width + tid;
	  out[index].x=(src1[index].x*src2[index].x - src1[index].y*src2[index].y);
	  out[index].y=(src1[index].x*src2[index].y + src1[index].y*src2[index].x);*/
}
__global__ void cuComplexConj(Complex *src,Complex *out,int size){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	int threadIndex = bid *blockDim.x + tid;
	int offset = blockDim.x*gridDim.x;
	for(int i=threadIndex; i< size; i+= offset){
		out[i].x=src[i].x;
		out[i].y= -src[i].y;
	}
}
__global__ void findWarpMaxIndex(float *out, const float *in, size_t N,int *index)
{
	// lenght = threads (BlockDim.x)
	__shared__ float sPartials[1024];
	__shared__ int sindex[1024];
	float max = in[0];
	int maxIndex = 0;
	const int tid = threadIdx.x;

	for (size_t i = blockIdx.x * blockDim.x + tid; i < N; i += blockDim.x * gridDim.x)
	{
		if(in[i] > max){
			max = in[i];
			maxIndex = i;
		}
	}
	sPartials[tid] = max;
	sindex[tid] = maxIndex;
	__syncthreads();

	for (int activeTrheads = blockDim.x / 2; activeTrheads > 0; activeTrheads /= 2)
	{
		if (tid < activeTrheads)
		{
			if( sPartials[tid] < sPartials[tid + activeTrheads]){
				sPartials[tid] = sPartials[tid + activeTrheads];
				sindex[tid] = sindex[tid + activeTrheads];
			}
		}
		__syncthreads();
	}

	if (tid == 0)
	{
		out[blockIdx.x] = sPartials[0];
		index[blockIdx.x]  = sindex[0];
	}
}
__global__ void cuComputeDxDy(int inIndex,int *maxIndex,int *dx,int *dy,int warpSize,int squareSize,int outIndex,int maximumShift){
	const int tid = threadIdx.x;
	// const int bid = blockIdx.x;
	//  int threadIndex = bid *blockDim.x + tid;
	//int offset = blockDim.x*gridDim.x;
	// int size = width * height;
	int x = maxIndex[inIndex] % warpSize;
	int y = maxIndex[inIndex] / warpSize;
	dx[outIndex] = x+1 - squareSize - 2;
	dy[outIndex] = y+1 - squareSize - 2;
	if(abs(dx[outIndex]) > maximumShift)
		dx[outIndex] = 0;
	if(abs(dy[outIndex]) > maximumShift)
		dy[outIndex] = 0;
}
__global__ void cuComputeDxDy1(int *maxIndex,int *dx,int *dy,int warpSize,int squareSize,int maximumShift){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	int threadIndex = bid *blockDim.x + tid;
	//int offset = blockDim.x*gridDim.x;
	// int size = width * height;
	int x = maxIndex[threadIndex] % warpSize +1;
	int y = maxIndex[threadIndex] / warpSize +1;
	dx[threadIndex] = x+1 - squareSize - 2;
	dy[threadIndex] = y+1 - squareSize - 2;
	if(abs(dx[threadIndex]) > maximumShift)
		dx[threadIndex] = 0;
	if(abs(dy[threadIndex]) > maximumShift)
		dy[threadIndex] = 0;
}
__global__ void cuComputeDxDy2(int *maxIndex,int *dx,int *dy,int warpSize,int squareSize,int maximumShift,int warpNum){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	int threadIndex = bid *blockDim.x + tid;
	//int offset = blockDim.x*gridDim.x;
	int size = warpNum;
	int offset = blockDim.x*gridDim.x;
	for(int i=threadIndex; i< size; i+= offset){
		int x = maxIndex[i] % warpSize +1;
		int y = maxIndex[i] / warpSize +1;
		dx[i] = x+1 - squareSize - 2;
		dy[i] = y+1 - squareSize - 2;
		if(abs(dx[i]) > maximumShift)
			dx[i] = 0;
		if(abs(dy[i]) > maximumShift)
			dy[i] = 0;
	}
}
__global__ void getmaxindexarray(int *out,int *src,int *srcindex,int index){
	out[index] = src[srcindex[0]];
}
void frameRegisterWarp(PREREFERENCE *pre_refr,TIF *tiff,COMMON &com){
	unsigned int width = tiff->width;
	unsigned int height = tiff->height;
	int length = tiff->length;
	//long int  warpdataSize = com.warpNum*com.warpDataLen;
	struct timeval start,stop;
	float diff;


	//20ms	
	//   gettimeofday(&start,NULL);
	// getwarpdata_kernel<<<com.warpNum,com.warpSize>>>(tiff->fdata,tiff->warpdata,com.para_d[2] ,com.raw_beginIndex_d,com.para_d[1],com.para_d[0]);
	getwarpdata_kernel<<<com.warpSize,com.warpSize>>>(tiff->fdata,tiff->warpdata,com.para_d[2] ,com.raw_beginIndex_d,com.para_d[1],com.para_d[0],com.para_d[6]);
	cudaDeviceSynchronize();
	//   gettimeofday(&stop,NULL);
	//   diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
	//   cout << "getwarpdata cost " << diff << " ms "<< endl;


	//cudaEvent_t startd,stopd;
	//float elapsedTimed;
	//cudaEventCreate(&startd);
	//cudaEventCreate(&stopd);
	//   gettimeofday(&start,NULL);
	//cudaEventRecord(startd,0);

	/*    for(int i=0;i<com.warpNum;i++){
	//int count = i * com.warpNumHeight + j;
	int count = i;
	int index = count * com.warpDataLen;
	float *point_in = tiff->warpdata+index;
	Complex *point_out = com.warp+index;

	cufftExecR2C(com.plan_small,point_in,point_out);



	}*/
	//

	cufftExecR2C(com.plan_batch,tiff->warpdata,com.warp);
	cudaDeviceSynchronize();
	//   gettimeofday(&stop,NULL);
	//   diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
	//   cout << "fft  cost " << diff << " us "<< endl;
	//}
	//cufftExecR2C(com.plan_batch,tiff->warpdata,warp);
	//cudaEventRecord(stopd,0);
	//cudaEventSynchronize(stopd);
	//cudaEventElapsedTime(&elapsedTimed,startd,stopd);
	//cout << "fft times  " << " : " << elapsedTimed << "ms." << endl;

	//   gettimeofday(&start,NULL);
	thrust::transform(com.d_warp.begin(),com.d_warp.end(),com.d_warp_conj.begin(),device_conj_functor());
	// cuComplexConj<<<256,256>>>(com.warp,com.warp_conj,com.warpdatasize_d[0]);
	//   gettimeofday(&stop,NULL);
	//   diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
	//   cout << "conj cost " << diff << " ms "<< endl;


	//    gettimeofday(&start,NULL);
	Complex *prewarp = thrust::raw_pointer_cast(&pre_refr->pre_warp[0]);

	cuComplexMulti<<<1024,1024>>>(com.warp_conj,prewarp,com.warpData,com.warpNum,com.warpDataLen);

	// gettimeofday(&start,NULL);

	cufftExecC2R(com.iplan_batch,com.warpData,com.raw_ifftres_warpdata);
	cudaDeviceSynchronize();
	// gettimeofday(&stop,NULL);
	// diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
	// cout << "ifft  cost " << diff << " us "<< endl;

	cuifftshift1<<<256,256>>>(com.raw_ifftres_warpdata,com.raw_ishift_warpdata,com.para_d[1],com.para_d[1],com.para_d[6],com.para_d[0]);

	thrust::device_vector<int> dxArray(com.warpNum);
	thrust::device_vector<int> dyArray(com.warpNum);
	int *dx = thrust::raw_pointer_cast(&dxArray[0]);
	int *dy = thrust::raw_pointer_cast(&dyArray[0]);
	thrust::device_vector<int> mInd(com.warpNum);
	int *mindex = thrust::raw_pointer_cast(&mInd[0]);
	// #pragma omp parallel for
	//  thrust::device_vector<Complex> d_dotRes(com.warpDataLen);
	//  Complex *warpData = thrust::raw_pointer_cast(&d_dotRes[0]);
	//   thrust::device_vector<float> C(com.warpDataLen);
	//  float *raw_c = thrust::raw_pointer_cast(&C[0]);
	//  thrust::device_vector<float> d_c(com.warpDataLen);
	//  float *d_raw_c = thrust::raw_pointer_cast(&d_c[0]);
	thrust::device_vector<float> partial_d(256);
	float *partial_small = thrust::raw_pointer_cast(&partial_d[0]);
	thrust::device_vector<int> partial_index_d(256);
	int *partial_index_small = thrust::raw_pointer_cast(&partial_index_d[0]);
	unsigned int sharedSize = 256 *sizeof(float);
	thrust::device_vector<float> max_d(1);
	float *max_small = thrust::raw_pointer_cast(&max_d[0]);
	thrust::device_vector<int> maxindex_d(1);
	int *maxindex_small = thrust::raw_pointer_cast(&maxindex_d[0]);
	// cufftResult r;

	//   gettimeofday(&stop,NULL);
	//   diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
	//   cout << "variable declarations: " << diff << " us "<< endl;

	//    gettimeofday(&start,NULL);
	for(int i=0; i< com.warpNum; i++){
		int index = i * com.warpDataLen;
		//r = cufftXtExec(com.plan_xt_r2c,)
		//  Complex *src1 = com.warp_conj+index;
		//	Complex *src2 = prewarp+index;
		//       Complex *warpData = com.warpData + index;
		// gettimeofday(&start,NULL);
		//      cuComplexMulti<<<256,256,0>>>(src1,src2,warpData,com.para_d[1],com.para_d[1]);
		// gettimeofday(&stop,NULL);
		// diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
		// cout << "********************************************* multi  cost " << diff << " us "<< endl;
		// thrust::transform(d_wap.begin(),d_wap.end(),d_pre_warp.begin(),d_dotRes.begin(),complex_multiplies_functor());

		//Complex *warpData = thrust::raw_pointer_cast(&d_dotRes[0]);
		//  gettimeofday(&start,NULL);
		//        cufftExecC2R(com.iplan_small,warpData,raw_c);
		//  gettimeofday(&stop,NULL);
		//  diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
		// cout << " *********************************************ifft cost " << diff << " us "<< endl;

		//   gettimeofday(&start,NULL);
		//     float *raw_c = com.raw_ifftres_warpdata + index;
		//     cuifftshift<<<com.warpSize,com.warpSize,0>>>(raw_c,d_raw_c,com.para_d[1],com.para_d[1]);
		//  gettimeofday(&stop,NULL);
		//  diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
		//  cout << "*********************************************cusiffthift  cost " << diff << " us "<< endl;

		// gettimeofday(&start,NULL);
		float *d_raw_c = com.raw_ishift_warpdata + index;
		findWarpMaxIndex<<<256,256>>>(partial_small,d_raw_c,com.para_d[0],partial_index_small);

		findWarpMaxIndex<<<1,256>>>(max_small,partial_small,256,maxindex_small);
		// cuComputeDxDy<<<1,1>>>(maxindex_d[0],partial_index,dx,dy,para_d[1],para_d[4],i,para_d[5]);
		// mInd[i] = partial_index[maxindex_d[0]];
		// gettimeofday(&stop,NULL);
		//  diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
		//  cout << "*********************************************findmax cost " << diff << " us "<< endl;

		//  gettimeofday(&start,NULL);
		getmaxindexarray<<<1,1>>>(mindex,partial_index_small,maxindex_small,i);
		//  gettimeofday(&stop,NULL);
		//  diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
		//  cout << "*********************************************manage maxindex cost " << diff << " us "<< endl;
	}
//   gettimeofday(&stop,NULL);
//   diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
//   cout << "register cost " << diff << " ms "<< endl;


//int *mindex = thrust::raw_pointer_cast(&mInd[0]);
//  gettimeofday(&start,NULL);
cuComputeDxDy1<<<1,com.warpNum,0>>>(mindex,dx,dy,com.para_d[1],com.para_d[4],com.para_d[5]);
//    cuComputeDxDy2<<<1,512>>>(mindex,dx,dy,com.para_d[1],com.para_d[4],com.para_d[5],com.para_d[6]);

//gettimeofday(&stop,NULL);
// diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
// cout << " *********** the small fft cost " << diff << " us "  << com.warpNum << endl;

//   gettimeofday(&start,NULL);
frameReformatWarpdata(tiff,dx,dy,com);
//   gettimeofday(&stop,NULL);
//   diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
//   cout << " *********** ************** the small shift cost " << diff << " ms "  << com.warpNum << endl;

}
