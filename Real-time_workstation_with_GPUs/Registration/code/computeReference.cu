
#include "function.h"

using namespace std;
__global__ void getwarpdata_k(float *data,float *warpdata,int width,int *index,int warpSize,int warpDataLen){
	const int tid = threadIdx.x;
	const int bid = blockIdx.x;
	// int length = width * height;
	//   int threadIndex = bid *BLOCK_NUM_SHIFT + tid;
	int srcstart = index[bid];
	int deststart = bid * warpDataLen;
	for(int i=0; i< warpSize;i++){
		int destIndex = deststart+tid*warpSize+i;
		int srcIndex  = srcstart+tid*width+i;
		warpdata[destIndex] = data[srcIndex];
	}
	// int offset = BLOCK_NUM_SHIFT*THREAD_NUM_SHIFT;
	//  for(int i=threadIndex; i< size; i+= offset){
}

void computeReference(TIF &tiff,PREREFERENCE *pre_refr,COMMON &com,int count){

    //float *fdata;
	cudaError a;

    //fdata = tiff.fdata;

    /*thrust::minus<float> opMinus;

	thrust::device_vector<float> ddata(fdata,fdata+tiff.length);
	thrust::device_vector<float> sumdata(tiff.length);
	thrust::device_vector<float> meandata(tiff.length);
	thrust::inclusive_scan(ddata.begin(),ddata.end(),sumdata.begin());

	float ave = sumdata[tiff.length-1] / tiff.length;

	thrust::device_vector<float> avedata(tiff.length);
	thrust::fill(avedata.begin(),avedata.end(),ave);

	thrust::transform(ddata.begin(),ddata.end(),avedata.begin(),meandata.begin(),opMinus);

	float *raw_point_data = thrust::raw_pointer_cast(&meandata[0]);

	unsigned int resSize = tiff.length;

    thrust::device_vector<Complex> d_res_fft(tiff.length);
    Complex *raw_point_res_fft = thrust::raw_pointer_cast(&d_res_fft[0]);*/
	// fftinit(tiff.width,tiff.height);

    int width = tiff.width;
    int height = tiff.height;

    float *fdata = tiff.fdata;
    int resSize = tiff.length;

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
//	fft(raw_point_data,raw_point_res_fft,tiff.width,tiff.height);
   // cufftExecR2C(com.plan_big,raw_point_data,raw_point_res_fft);
    cufftExecR2C(com.plan_big,com.raw_point_data,com.raw_point_res_fft);

	//thrust::device_vector<Complex> d_res_conj(tiff.length);
	//if(count == 0)
	//	pre_refr->pre_xlat.resize(tiff.length);

    //thrust::device_vector<Complex> d_xlat_tmp(tiff.length);
    //Complex *raw_point_res_conj = thrust::raw_pointer_cast(&d_xlat_tmp[0]);

    thrust::transform(com.d_res_fft.begin(),com.d_res_fft.end(),com.d_xlat_tmp.begin(),device_conj_functor());
	//cout <<"-----------------------------" << pre_refr->pre_xlat.size() << endl;
    thrust::transform(com.d_xlat_tmp.begin(),com.d_xlat_tmp.end(),pre_refr->pre_xlat.begin(),pre_refr->pre_xlat.begin(),complex_plus_functor());
	pre_refr->pre_xlat_size = resSize;
	pre_refr->pre_xlat_xsize = tiff.width;
	pre_refr->pre_xlat_ysize = tiff.height;


	long long int warpdataSize = com.warpNum*com.warpDataLen;
	//if(count == 0)
	//pre_refr->pre_warp.resize(warpdataSize);
	//count ++;

	pre_refr->pre_warp_size = com.warpNum;
	pre_refr->pre_warp_data_size  = com.warpDataLen;
	pre_refr->pre_warp_data_xsize  = com.warpSize;
	pre_refr->pre_warp_data_ysize  = com.warpSize;

    //thrust::device_vector<Complex> d_warp_tmp(warpdataSize);
    //Complex *point_fftRes = thrust::raw_pointer_cast(&d_warp_tmp[0]);

    //thrust::device_vector<int> index_d(com.beginIndex.begin(),com.beginIndex.end());
    //int *index_p = thrust::raw_pointer_cast(&index_d[0]);
    thrust::device_vector<int> para_d(3);
	para_d[0] = com.warpDataLen;
	para_d[1] = com.warpSize;
	para_d[2] = tiff.width;

    getwarpdata_k<<<com.warpNum,com.warpSize>>>(tiff.fdata,tiff.warpdata,para_d[2] ,com.raw_beginIndex_d,para_d[1],para_d[0]);
    getWarpData(tiff,com.raw_point_warptmp,com);

    thrust::transform(com.d_warp_tmp.begin(),com.d_warp_tmp.end(),pre_refr->pre_warp.begin(),pre_refr->pre_warp.begin(),complex_plus_functor());


	if(DEBUG)
		cout << "prepare reference image for registration ok!" << endl;	
}
