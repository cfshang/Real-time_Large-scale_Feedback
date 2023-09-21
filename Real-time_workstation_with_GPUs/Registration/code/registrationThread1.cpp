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

/*extern EthFrmRcvPool * pEthRcvPool[2];
extern XmlConfig *xmlConf;
extern bool is_stop;
extern bool flags;
extern bool first;
extern TIF pretiff[GPU_MAX];
extern TIF tiff[GPU_MAX];
extern int do_shutdown;*/
void registrationThread1(PARAMSTHREAD *para){
    int deviceID = 0;
    size_t size_dev;
    int data_size = pEthRcvPool[deviceID]->getSizeBuf();

    //omp_set_num_threads(GPU_MAX);
//#pragma omp parallel for
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

    /*int count = 0;
    int length = para->com[0].length;
    int exeNumGPU = para->com[0].nFramePerRcvBuf;
    char outputfile[300];
    //char *filename = "CASIA";
    int cnt=0;
    unsigned short *pt[BUFFER_NUM];
    short *reg[BUFFER_NUM];
    //omp_set_num_threads(exeNumGPU);
    bool ifdealModel = true;
    bool ifdealPic = false;
    is_stop = false;
    bool ifstoreModel = xmlConf->getIfStoreModel();
    bool ifstoreROI = xmlConf->getIfStoreRoi();
    unsigned int regNumber = xmlConf->getRegNumber();
    unsigned int modelNumber = xmlConf->getModelNumber();
    unsigned int numModelPerETH = xmlConf->getModelNumber()/2;
    string modeldataStore = xmlConf->getModelStorePath();
    string roivalueStore = xmlConf->getRoiValueStorePath();
    int nRcvBuf = xmlConf->getnRcvBuf();
    while (!is_stop)
    {

        reg[0] = pEthRcvPool[0]->curBufIndexToProc();
        reg[1] = pEthRcvPool[1]->curBufIndexToProc();
        pt[0] = pEthRcvPool[0]->curBufToProc();
        pt[1] = pEthRcvPool[1]->curBufToProc();
        int sizebuf = pEthRcvPool[0]->getSizeBuf();

        int modInOnePool = numModelPerETH;

        if(ifdealModel && count < modInOnePool){
            int ntmp;
            if(ifstoreModel){
                for(int i=0; i < exeNumGPU; i++){
                    for(int k=0;k<BUFFER_NUM;k++){
                        ntmp = cnt + k + i*BUFFER_NUM;
                        //string timep = getTime();
                        if(ntmp < modelNumber){
                            sprintf(outputfile,"%s_%d_%d.tif",modeldataStore.c_str(),ntmp,reg[k][i]);
                            int res = writeTIF(outputfile,&tiff[0],pt[k]+i*length);
                            if(!res){
                                cout << "The ModelImage write error!"<< ntmp <<endl;
                                exit(-1);
                            }
                        }
                    }
                }
            }
            if(ntmp < modelNumber){
                // cout << "copy to data model" << endl;
                prepareModel(count,sizebuf,para,modelNumber,regNumber);
            }
            int rangeEnd = (count + para->com[0].nFramePerRcvBuf)*2 - 1;
            if(rangeEnd < modelNumber)
                cout << " Prepare model number : "  << count*2 << " ~~ "<< rangeEnd << endl;
            else
                cout << " Prepare model number : "  << count*2 << " ~~ "<< modelNumber-1 << endl;

            count += para->com[0].nFramePerRcvBuf;
            cnt += (exeNumGPU*BUFFER_NUM);

            for(int i = 0; i < 2; i++){
                pEthRcvPool[i]->finishCurBufProc();
            }

            if(count >= modInOnePool){
                for(int i = 0; i < 2; i++){
                    pEthRcvPool[i]->setIdxVar();
                    pEthRcvPool[i]->changeDealStaVar();
                }
                usleep(1000);

                ifdealModel = false;
                cnt = 0;
                ifdealPic = true;
                cout << "Pictrue data start !" << endl;
            }



        }
        else if(ifdealPic){
            if(first){
                first = false;
                cnt = 0;

            }

            while(((pEthRcvPool[0]->getidxRcvBuf()- pEthRcvPool[0]->getidxRcvBufToProc()+ nRcvBuf) % nRcvBuf) >0 ||
                  ((pEthRcvPool[1]->getidxRcvBuf()- pEthRcvPool[1]->getidxRcvBufToProc()+ nRcvBuf) % nRcvBuf) >0){
                if(!flags){
                    pt[0] = pEthRcvPool[0]->curBufToProc_deal();
                    pt[1] = pEthRcvPool[1]->curBufToProc_deal();
                   // gettimeofday(&start,NULL);
                    copyToDevice(sizebuf,para);

                    //#pragma omp parallel for
                    for(int i=0; i < exeNumGPU; i++){
                        for(int k=0;k<BUFFER_NUM;k++){
                            int n = cnt + k + i*BUFFER_NUM;
                            //string timep = getTime();
                            if(ifstoreROI)
                                computeROI(reg[k][i],pt[k]+i*length,para->com,n,regNumber);


                        }
                    }

                    cnt += (exeNumGPU*BUFFER_NUM);
                    for(int i = 0; i < 2; i++){
                        pEthRcvPool[i]->finishDealBufProc();
                       // pEthRcvPool[i]->finishCurBufProc();
                    }
                      //gettimeofday(&stop,NULL);
                      //diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
                      //cout << "GPU computed : " << cnt  << "    ----> " << diff << " ms. "<< endl;
                    // if(!pEthRcvPool[0]->gettotalRcvBufToProc()  && (!pEthRcvPool[1]->gettotalRcvBufToProc())){
                    // break;
                    // }
                }
                else{
                    is_stop = true;

                    break;
                }



            }
            if(!pEthRcvPool[0]->gettotalRcvBufToProc()  && (!pEthRcvPool[1]->gettotalRcvBufToProc())){
                is_stop = true;
                cout << "end!" << endl;
            }

        }

        //std:cout << ".................................copy ok!" << endl;

    }
    if(ifstoreROI)
        writeROI(roivalueStore,regNumber);
    finishMem(para);*/
}
