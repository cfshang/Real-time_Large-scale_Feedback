#include "function.h"
#include "EthFrmRcvPool.h"
#include "XmlConfig.h"
#include "ThreadFlags.h"
using namespace std;

extern EthFrmRcvPool * pEthRcvPool[2];
extern XmlConfig *xmlConf;
extern ThreadFlags *flags;
extern TIF pretiff[GPU_MAX];
extern TIF tiff[GPU_MAX];
void buffProcessingRegistration2(PARAMSTHREAD *para){
    int deviceID = 1;
    int count = 0;
    int length = para->com[deviceID].length;
    int nFramePerRcvBuf = para->com[deviceID].nFramePerRcvBuf;
    char outputfile[300];
    //char *filename = "CASIA";
    int cnt= deviceID;
    unsigned short *pt[BUFFER_NUM];
    short *reg[BUFFER_NUM];
    //omp_set_num_threads(exeNumGPU);

    bool first = true;
   // bool ifstoreModel = xmlConf->getIfStoreModel();
    bool ifstoreROI = xmlConf->getIfStoreRoi();
    unsigned int regNumber = xmlConf->getRegNumber();
    //unsigned int modelNumber = xmlConf->getModelNumber();
    //unsigned int numModelPerETH = xmlConf->getModelNumber()/2;
    //string modeldataStore = xmlConf->getModelStorePath();
    string roivalueStore = xmlConf->getRoiValueStorePath();
    int nRcvBuf = xmlConf->getnRcvBuf();
    // pt[1] = pEthRcvPool[1]->curBufToProc();
     int sizebuf = pEthRcvPool[deviceID]->getSizeBuf();
    while (flags->ifregistration2)
    {
        if(flags->syncifdealPic2){

                if(((pEthRcvPool[deviceID]->getidxRcvBuf()- pEthRcvPool[deviceID]->getidxRcvBufToProc()+ nRcvBuf) % nRcvBuf) >0 &&pEthRcvPool[deviceID]->gettotalRcvBufToProc()){
                    //if(!flags){
                        //pt[deviceID] = pEthRcvPool[deviceID]->curBufToProc_deal();
                        //reg[deviceID] = pEthRcvPool[deviceID]->curBufIndexToProc_deal();
                        //pt[1] = pEthRcvPool[1]->curBufToProc_deal();
                       // gettimeofday(&start,NULL);
                    reg[deviceID] = pEthRcvPool[deviceID]->curBufIndexToProc_deal();
                 //   reg[deviceID] = pEthRcvPool[deviceID]->curBufIndexToProc();
                    //reg[1] = pEthRcvPool[1]->curBufIndexToProc();
                    pt[deviceID] = pEthRcvPool[deviceID]->curBufToProc_deal();
                  //  pt[deviceID] = pEthRcvPool[deviceID]->curBufToProc();
                    registrationThread2(para);

                    //#pragma omp parallel for
                    /*for(int i=0; i < nFramePerRcvBuf; i++){
                        //for(int k=0;k<BUFFER_NUM;k++){
                            int n = cnt + i*BUFFER_NUM;
                            //string timep = getTime();
                            if(ifstoreROI)
                                computeROI(reg[deviceID][i],pt[deviceID]+i*length,para->com,n,regNumber);


                        //}
                    }

                    cnt += (nFramePerRcvBuf*BUFFER_NUM);*/

                        pEthRcvPool[deviceID]->finishCurBufProc_deal();
                        //pEthRcvPool[deviceID]->finishCurBufProc();
                            if(first){
                                first = false;
                                flags->synccomputeroi2 = true;
                            }

                        // if(!pEthRcvPool[0]->gettotalRcvBufToProc()  && (!pEthRcvPool[1]->gettotalRcvBufToProc())){
                        // break;
                        // }
                    //}
                    //else{
                        //is_stop = true;

                       // break;
                    //}



                }
                /*if(!pEthRcvPool[deviceID]->gettotalRcvBufToProc()){
                    is_stop2 = true;
                    //writeroiflags = true;
                    cout << "Registration2 end!" << endl;
                }*/


            //std:cout << ".................................copy ok!" << endl;
        }


    }

}
