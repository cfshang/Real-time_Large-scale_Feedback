
#include <iostream>
#include <stdio.h>
#include <cufft.h>

#include <cmath>

#include "EthFrmRcvPool.h"
#include <omp.h>
#include <pthread.h>
#include <sys/time.h>
#include <string.h>
#include "function.h"
using namespace std;
#define GPU_COMPUTE_CELL 2048*2048
#define PICTUREWIDTH 2048
#define PICTUREHEIGHT 2048

extern EthFrmRcvPool * pEthRcvPool[2];
//__device__ char data_dev_pointer[1024*1024*512];
//extern COMMON com[GPU_MAX];
extern TIF pretiff[GPU_MAX];
extern TIF tiff[GPU_MAX];


static int countReference[GPU_MAX] = {0,0};
void singleBuffDealReference(int number,size_t data_size,PARAMSTHREAD *para,unsigned int referenceNumber,unsigned int regNumber)
{
	//unsigned short *data_dev[GPU_MAX];


}
// use openMP
int prepareReference(int number,int len,PARAMSTHREAD *para,unsigned int _referenceNumber,unsigned int _regNumber)
{	

    //int count_gpu = 2;
    unsigned int referenceNumber= _referenceNumber;
    unsigned int regNumber= _regNumber;
    //referenceNumber
    //regNumber
	size_t data_size = len;
   // singleBuffDealReference(number,data_size,para,referenceNumber,regNumber);

    size_t size_dev[GPU_MAX];
    int indsBegin[GPU_MAX];
    cudaEvent_t start[GPU_MAX],stop[GPU_MAX];
    float elapsedTime[GPU_MAX];
    //omp_set_num_threads(GPU_MAX);
//#pragma omp parallel for
    for(int i = 0; i < GPU_MAX; i++)
    {
        //std::cout << "copy to Device ok"  << "   ....   " << i << "...."<< endl;
        cudaSetDevice(i);

        unsigned short *data_dev[2];
        unsigned short *data_host[2];
        short *data_index_dev[2];
        short *data_index_host[2];
        float *data_float_dev[2];
        float *data_float_host[2];
        //cudaEventCreate(&start[i]);
        //cudaEventCreate(&stop[i]);
        int width = para->com[i].width;
        int height = para->com[i].height;
        int length = para->com[i].length;
        //int length = width * height;
        tiff[i].width = width;
        tiff[i].height = height;
        tiff[i].length = length;
        int referenceOnePool = referenceNumber / 2;
        int tmp = referenceOnePool/ para->com[i].nFramePerRcvBuf;
        tmp = tmp * para->com[i].nFramePerRcvBuf;
        int num = para->com[i].nFramePerRcvBuf;
        if(number >= tmp )
            num = referenceOnePool-tmp;
        for(int j=0;j<2;j++){
            data_host[j] = pEthRcvPool[j]->curBufToProc_refer();
            data_index_host[j] = pEthRcvPool[j]->curBufIndexToProc_refer();
            data_float_host[j] = pEthRcvPool[j]->curBufFloatToProc_refer();
            cudaError a = cudaHostGetDevicePointer(&data_dev[j],data_host[j],0);
            if(a != cudaSuccess){
                printf("The cudaHostGetDevicePointer data_dev error in preparereference.cu, %d\n",i);
                exit(-1);
            }
            a = cudaHostGetDevicePointer(&data_index_dev[j],data_index_host[j],0);
            if(a != cudaSuccess){
                printf("The cudaHostGetDevicePointer data_index_dev error in preparereference.cu, %d\n",j);
                exit(-1);
            }
            a = cudaHostGetDevicePointer(&data_float_dev[j],data_float_host[j],0);
                if(a != cudaSuccess){
                printf("The cudaHostGetDevicePointer data_float_dev error in preparereference.cu, %d\n",j);
                exit(-1);
                }

            float *pfdata = thrust::raw_pointer_cast(&(para->com[i].fdata_d[0]));
            //thrust::device_vector<float> fdata_d(data_dev[j],data_dev[j]+data_size);
            //float *pfdata = thrust::raw_pointer_cast(&fdata_d[0]);
            cudaMemcpyAsync(pfdata,data_float_host[j],data_size*sizeof(float),cudaMemcpyHostToDevice,0);

            unsigned short *psdata = data_dev[j];
            short *dataIndex = data_index_dev[j];

            for(int k=0; k<num; k++){
                int refrIndex = dataIndex[k];
                PREREFERENCE *pre = &(para->pre_refr[i][refrIndex]);
                int index = k * length;
                tiff[i].fdata = pfdata + index;
                tiff[i].sdata = psdata + index;
                computeReference(tiff[i],pre,para->com[i],countReference[i]);
                countReference[i] ++;
            }
        }
        if(countReference[i] == referenceNumber){
            //thrust::device_vector<float> tmpNumXlat(tiff[i].length);
            float avenum = referenceNumber / regNumber;
            thrust::fill(para->com[i].tmpNumXlat.begin(),para->com[i].tmpNumXlat.end(),avenum);
            long int warpdataSize = para->com[i].warpNum* para->com[i].warpDataLen;
            //thrust::device_vector<float> tmpNumWarp(warpdataSize);
            thrust::fill(para->com[i].tmpNumWarp.begin(),para->com[i].tmpNumWarp.end(),avenum);
            //thrust::divides<float> opDivides;
            for(int k=0; k<regNumber; k++){
                thrust::transform(para->pre_refr[i][k].pre_xlat.begin(),para->pre_refr[i][k].pre_xlat.end(),para->com[i].tmpNumXlat.begin(),para->pre_refr[i][k].pre_xlat.begin(),complex_devides_functor());
                thrust::transform(para->pre_refr[i][k].pre_warp.begin(),para->pre_refr[i][k].pre_warp.end(),para->com[i].tmpNumWarp.begin(),para->pre_refr[i][k].pre_warp.begin(),complex_devides_functor());
            }
        }
    }

	return 1;
}
