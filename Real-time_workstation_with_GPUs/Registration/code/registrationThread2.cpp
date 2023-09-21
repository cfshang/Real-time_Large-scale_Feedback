#include "function.h"
#include "EthFrmRcvPool.h"
#include "XmlConfig.h"
#include <iostream>
#include <stdio.h>
#include <cufft.h>
#include <cmath>
#include <omp.h>
#include <pthread.h>
#include <sys/time.h>
#include <string.h>

using namespace std;

extern TIF tiff[GPU_MAX];
extern EthFrmRcvPool * pEthRcvPool[2];

void registrationThread2(PARAMSTHREAD *para){
    int deviceID = 1;
    size_t size_dev;
    int data_size = pEthRcvPool[deviceID]->getSizeBuf();

    //cout << " Registration Thread 2 start!" << endl;

        cudaSetDevice(deviceID);
        unsigned short *data_dev;
        unsigned short *data_host;
        short *data_index_dev;
        short *data_index_host;
        float *data_float_dev;
        float *data_float_host;
        struct timeval start,stop;
        float diff;

        int width = para->com[deviceID].width;
        int height = para->com[deviceID].height;
        int length = width * height;
        //int length = width * height;
        //      gettimeofday(&start,NULL);
        data_host = pEthRcvPool[deviceID]->curBufToProc_deal();
        data_index_host = pEthRcvPool[deviceID]->curBufIndexToProc_deal();
        data_float_host = pEthRcvPool[deviceID]->curBufFloatToProc_deal();
        //data_host = pEthRcvPool[i]->curBufToProc();
        //data_index_host = pEthRcvPool[i]->curBufIndexToProc();
        //data_float_host = pEthRcvPool[i]->curBufFloatToProc();
        cudaError_t a = cudaHostGetDevicePointer(&data_dev,data_host,0);
        if(a != cudaSuccess){
            printf("The cudaHostGetDevicePointer error, %d\n",deviceID);
            exit(-1);
        }
        a = cudaHostGetDevicePointer(&data_index_dev,data_index_host,0);
        if(a != cudaSuccess){
            printf("The cudaHostGetDevicePointer error, %d\n",deviceID);
            exit(-1);
        }
        a = cudaHostGetDevicePointer(&data_float_dev,data_float_host,0);
        if(a != cudaSuccess){
            printf("The cudaHostGetDevicePointer error, %d\n",deviceID);
            exit(-1);
        }
        //cudaMemcpy(data_dev[i],&data_host[indsBegin[i]],sizeof(unsigned short)*size_dev[i],cudaMemcpyHostToDevice);
        //computeDevice(data_host,data_dev[i],size_dev[i],indsBegin[i],i);
        // int width = tiff[gid].width;

        tiff[deviceID].width = width;
        tiff[deviceID].height = height;
        tiff[deviceID].length = length;
        int num = para->com[deviceID].nFramePerRcvBuf;
        unsigned short *psdata = data_dev;
        short *dataIndex = data_index_dev;
        // float *pfdata = data_float_dev;
        //   thrust::device_vector<float> fdata_d(data_dev,data_dev+data_size);

        //      float *pfdata = data_float_dev;
        //  cudaError_t a;
        //      gettimeofday(&start,NULL);
        float *pfdata = thrust::raw_pointer_cast(&(para->com[deviceID].fdata_d[0]));
        //  float *pfdata = para->com[i].fdata_device;
        /*    cudaError_t b=cudaMemcpy(pfdata,data_float_host,data_size*sizeof(float),cudaMemcpyHostToDevice);
              if(b != cudaSuccess){
              std::cout << " cudamemcpy error : " << b << endl;
              printf(" -- %s \n",b);
              exit(-1);
              }*/
        cudaMemcpyAsync(pfdata,data_float_host,data_size*sizeof(float),cudaMemcpyHostToDevice,0);


        //dataShortToFloat<<<512,512>>>(pfdata,pfdata,1024);
        //  cudaDeviceSynchronize();
        //  cudaStreamSynchronize();

        //      gettimeofday(&stop,NULL);
        //      diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
        //      cout << " ************* the transform cost : "  << diff << " ms. "<< endl;


        for(int k=0; k<num; k++){
            int refrIndex = dataIndex[k];
            if(refrIndex >-1){
                PREREFERENCE *pre = &(para->pre_refr[deviceID][refrIndex]);
                int index = k * length;
                tiff[deviceID].fdata = pfdata + index;

                tiff[deviceID].sdata = psdata + index;
                // gettimeofday(&start,NULL);
                frameRegisterXlat(pre,&tiff[deviceID],para->com[deviceID]);
                //  gettimeofday(&stop,NULL);
                //   diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
                //   cout << " ************* the whole image cost : "  << diff << " ms. "<< endl;

                //  gettimeofday(&start,NULL);
                frameRegisterWarp(pre,&tiff[deviceID],para->com[deviceID]);
                //   gettimeofday(&stop,NULL);
                //   diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
                //   cout << " ********************** the small image cost : "  << diff << " ms. "<< endl;
            }
            else{
                cout << "RegistrationThread2 finished!" << endl;
                break;
            }

        }


}
