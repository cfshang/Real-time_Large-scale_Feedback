#include <iostream>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <vector>
#include "function.h"
#include <assert.h>
using namespace std;
#define BLOCK_NUM_SHIFT 512
#define THREAD_NUM_SHIFT 1024

__global__ void computeSum(float *out, const float *in, size_t N)
{
	// lenght = threads (BlockDim.x)
	__shared__ float sPartials[1024];
	// __shared__ int sindex[1024];
	float sum = 0;
	// int maxIndex = 0;
	const int tid = threadIdx.x;

	for (size_t i = blockIdx.x * blockDim.x + tid; i < N; i += blockDim.x * gridDim.x)
	{
		sum += in[i];
	}
	sPartials[tid] = sum;
	__syncthreads();

	for (int activeTrheads = blockDim.x / 2; activeTrheads > 0; activeTrheads /= 2)
	{
		if (tid < activeTrheads)
		{
			sPartials[tid] += sPartials[tid + activeTrheads];
		}
		__syncthreads();
	}

	if (tid == 0)
	{
		out[blockIdx.x] = sPartials[0];
	}
}
__global__ void computeMean(float *out, const float *in,float *sum, size_t N)
{
	float ave = sum[0] / N;
	const int tid = threadIdx.x;

	for (size_t i = blockIdx.x * blockDim.x + tid; i < N; i += blockDim.x * gridDim.x)
	{
		out[i] = in[i] - ave;
	}
}
__global__ void cufftshift(float *src,float *out,int width,int height){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	size_t xshift = width / 2;
	size_t yshift = height / 2;
	size_t size = width * height;
	int threadIndex = bid *BLOCK_NUM_SHIFT + tid;
	int offset = BLOCK_NUM_SHIFT*THREAD_NUM_SHIFT;
	for(int i=threadIndex; i< size; i+= offset){
		size_t yIdx = i / width;
		size_t xIdx = i % width;
		size_t outY = (yIdx + yshift) % height;
		size_t outX = (xIdx + xshift) % width;
		size_t outIdx = outX + width*outY;
		out[outIdx] = src[i];
	}

}
__global__ void findMaxIndex(float *out, const float *in, size_t N,int *index)
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
__global__ void imageShift(float *fdest,unsigned short *sdest,int width,int height,int *partial_index,int *maxindex){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	int index = partial_index[maxindex[0]];
	int maxx = index % width;
	int maxy = index / width;
	int tmp = ((double)width) / 2- 0.5 + 1;
	int dx = maxx +1 - tmp - 1;
	tmp = (double(height)) / 2- 0.5 + 1;
	int dy = maxy +1 - tmp - 1;
	size_t size = width * height;
	int threadIndex = bid *BLOCK_NUM_SHIFT + tid;
	int offset = BLOCK_NUM_SHIFT*THREAD_NUM_SHIFT;

	if(dy >= 0 && dx >= 0){
		for(int i=threadIndex; i< size; i+= offset){
			int desty = i / width;
			int destx = i % width;
			if(desty < (height-dy) && destx < (width-dx)){
				int srcy = desty + dy;
				int srcx = destx + dx;
				int src = srcy * width + srcx;
				// fdest[i] = (float)ssrc[src];
				sdest[i] = (unsigned short)fdest[src];
			}
		}
	}
	else if(dy >= 0 && dx <=0){
		for(int i=threadIndex; i< size; i+= offset){
			int desty = i / width;
			int destx = i % width;
			if(desty < (height-dy) && destx >= -dx){
				int srcy = desty + dy;
				int srcx = destx + dx;
				int src = srcy * width + srcx;
				// fdest[i] = (float)ssrc[src];
				sdest[i] = (unsigned short)fdest[src];
			}
		}

	}
	else if(dy <= 0 && dx >=0){
		for(int i=threadIndex; i< size; i+= offset){
			int desty = i / width;
			int destx = i % width;
			if(desty >= -dy && destx <(width - dx)){
				int srcy = desty + dy;
				int srcx = destx + dx;
				int src = srcy * width + srcx;
				// fdest[i] = (float)ssrc[src];
				sdest[i] = (unsigned short)fdest[src];
			}
		}

	}
	else if(dy <= 0 && dx <=0){

		for(int i=threadIndex; i< size; i+= offset){
			int desty = i / width;
			int destx = i % width;
			if(desty >= -dy && destx >= -dx){
				int srcy = desty + dy;
				int srcx = destx + dx;
				int src = srcy * width + srcx;
				// fdest[i] = (float)ssrc[src];
				sdest[i] = (unsigned short)fdest[src];
			}
		} 
	}


}
__global__ void imageShift_fdata(float *fdest,unsigned short *sdata,int width,int height){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	int threadIndex = bid *blockDim.x + tid;
	int offset = blockDim.x * gridDim.x;
	int size = width * height;
	for(int i=threadIndex; i< size; i+= offset){
		fdest[i] = (float)sdata[i];
	}
}
void frameRegisterXlat(PREREFERENCE *pre_refr,TIF *tiff,COMMON &com){
	struct timeval start,stop;
	float diff;
	// gettimeofday(&start,NULL);
	int width = tiff->width;
	int height = tiff->height;

	float *fdata = tiff->fdata;
	int resSize = tiff->length;

	//thrust::device_vector<float> meandata(tiff->length);
	// float *raw_point_data = com.raw_point_data;
	// thrust::inclusive_scan(ddata.begin(),ddata.end(),sumdata.begin());
	// thrust::device_vector<float> partial_sum_d(4096);
	//   float *partial_sum = com.partial_sum;
	computeSum<<<4096,1024>>>(com.partial_sum,fdata,resSize);
	// thrust::device_vector<float> sum_d(1);


	computeSum<<<1,1024>>>(com.sum,com.partial_sum,4096);
	//float sum_data = com.sum[0];
	computeMean<<<BLOCK_NUM_SHIFT,THREAD_NUM_SHIFT>>>(com.raw_point_data,fdata,com.sum,resSize);


	//thrust::device_vector<Complex> d_res_fft(tiff->length);
	//Complex *raw_point_res_fft = thrust::raw_pointer_cast(&d_res_fft[0]);

	//fft(raw_point_data,raw_point_res_fft,tiff->width,tiff->height);
	cufftExecR2C(com.plan_big,com.raw_point_data,com.raw_point_res_fft);

	//thrust::device_vector<Complex> pre_xlat_fft(pre_refr->pre_xlat,pre_refr->pre_xlat+resSize);
	//Complex *raw_pre_xlat_fft = thrust::raw_pointer_cast(&pre_refr->pre_xlat[0]);
	//thrust::device_vector<Complex> resDot(resSize);
	//Complex *raw_resDot = thrust::raw_pointer_cast(&resDot[0]);
	thrust::transform(pre_refr->pre_xlat.begin(),pre_refr->pre_xlat.end(),com.d_res_fft.begin(),com.resDot.begin(),complex_multiplies_functor());

	//thrust::device_vector<float> ifft_res(resSize);
	//float *raw_ifft_res = thrust::raw_pointer_cast(&ifft_res[0]);
	//ifft(raw_resDot,raw_ifft_res,width,height);
	cufftExecC2R(com.iplan_big,com.raw_resDot,com.raw_ifft_res);

	//thrust::device_vector<float> fftshift_res(resSize);
	//float *raw_fftshift_res = thrust::raw_pointer_cast(&fftshift_res[0]);
	//fftshift2D(h_raw_ifft_res,width,height);
	cufftshift<<<BLOCK_NUM_SHIFT,THREAD_NUM_SHIFT,0>>>(com.raw_ifft_res,com.raw_fftshift_res,tiff->width,tiff->height);
	//thrust::device_vector<float> partial_d(4096);
	// *partial = thrust::raw_pointer_cast(&partial_d[0]);
	//thrust::device_vector<int> partial_index_d(4096);
	//int *partial_index = thrust::raw_pointer_cast(&partial_index_d[0]);
	//unsigned int sharedSize = 1024 *sizeof(float);
	findMaxIndex<<<4096,1024>>>(com.partial_sum,com.raw_fftshift_res,resSize,com.partial_index);

	// cout << max_h[589] << endl;
    //thrust::device_vector<float> max_d(1);
    //float *max = thrust::raw_pointer_cast(&max_d[0]);
    //thrust::device_vector<int> maxindex_d(1);
    //int *maxindex = thrust::raw_pointer_cast(&maxindex_d[0]);
    findMaxIndex<<<1,1024>>>(com.maxdata,com.partial_sum,4096,com.maxindex);
	//MAXINDEX maxIndex;

	//findMaxIndex(h_raw_ifft_res,height,width,maxIndex);

    //thrust::device_vector<unsigned short> sdata(tiff->sdata,tiff->sdata+tiff->length);
    //unsigned short *ssrc = thrust::raw_pointer_cast(&sdata[0]);

    imageShift<<<1024,THREAD_NUM_SHIFT,0>>>(tiff->fdata,tiff->sdata,tiff->width,tiff->height,com.partial_index,com.maxindex);
    imageShift_fdata<<<1024,THREAD_NUM_SHIFT,0>>>(tiff->fdata,tiff->sdata,tiff->width,tiff->height);
    //gettimeofday(&stop,NULL);
    //diff = (stop.tv_sec-start.tv_sec)*1000000+(stop.tv_usec-start.tv_usec);
   // cout << " ********************** the whole image cost : "  << diff << " us. "<< endl;
	if(DEBUG)
		cout << "frame registration xlat ok!" << endl;
	
}
