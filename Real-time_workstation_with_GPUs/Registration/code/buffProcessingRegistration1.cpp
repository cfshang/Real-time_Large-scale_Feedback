                                                                                                                                                                                                                               #include "function.h"
#include "EthFrmRcvPool.h"
#include "XmlConfig.h"
#include "ThreadFlags.h"
using namespace std;

extern EthFrmRcvPool * pEthRcvPool[2];
extern XmlConfig *xmlConf;
extern TIF pretiff[GPU_MAX];
extern TIF tiff[GPU_MAX];
extern ThreadFlags *flags;
void buffProcessingRegistration1(PARAMSTHREAD *para){
    int deviceID = 0;
    int count = 0;
    int length = para->com[deviceID].length;
    int nFramePerRcvBuf = para->com[deviceID].nFramePerRcvBuf;
    char outputfile[300];
    //char *filename = "CASIA";
    int cnt= deviceID;
    unsigned short *pt[BUFFER_NUM];
    short *reg[BUFFER_NUM];
    bool first = true;
    //omp_set_num_threads(exeNumGPU);

   // bool ifstoreModel = xmlConf->getIfStoreModel();
    bool ifstoreROI = xmlConf->getIfStoreRoi();
    unsigned int regNumber = xmlConf->getRegNumber();
    //unsigned int modelNumber = xmlConf->getModelNumber();
    //unsigned int numModelPerETH = xmlConf->getModelNumber()/2;
    //string modeldataStore = xmlConf->getModelStorePath();
    string roivalueStore = xmlConf->getRoiValueStorePath();
    int nRcvBuf = xmlConf->getnRcvBuf();
    bool ifstoreimg = xmlConf->getIfStoreResultImage();
    int sizebuf = pEthRcvPool[deviceID]->getSizeBuf();
    struct timeval start, end;
    long timing;
    while (flags->ifregistration1)
    {
        if(flags->syncifdealPic1){

           // pt[1] = pEthRcvPool[1]->curBufToProc();

                if(((pEthRcvPool[deviceID]->getidxRcvBuf()- pEthRcvPool[deviceID]->getidxRcvBufToProc()+ nRcvBuf) % nRcvBuf) >0 && pEthRcvPool[deviceID]->gettotalRcvBufToProc()){
                    //if(!flags){
                        //pt[deviceID] = pEthRcvPool[deviceID]->curBufToProc_deal();
                        //reg[deviceID] = pEthRcvPool[deviceID]->curBufIndexToProc_deal();
                        //pt[1] = pEthRcvPool[1]->curBufToProc_deal();
                       // gettimeofday(&start,NULL);

                     //gettimeofday(&start,NULL);
                      reg[deviceID] = pEthRcvPool[deviceID]->curBufIndexToProc_deal();
                        //reg[deviceID] = pEthRcvPool[deviceID]->curBufIndexToProc();
                        //reg[1] = pEthRcvPool[1]->curBufIndexToProc();
                        pt[deviceID] = pEthRcvPool[deviceID]->curBufToProc_deal();
                       // pt[deviceID] = pEthRcvPool[deviceID]->curBufToProc();

                        registrationThread1(para);

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

                            //gettimeofday(&end,NULL);
                            //timing =(end.tv_sec -start.tv_sec)*1000+(end.tv_usec -start.tv_usec)/1000;
                            //  cout << "cost 4  "<< timing  << " ms"<< endl;

                            if(first){
                                first = false;
                                flags->synccomputeroi1 = true;
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
                    //ifdealPic1 = true;
                    //writeflags = true;
                    is_stop1 = true;
                    cout << "Registration1 end!" << endl;
                }*/


            //std:cout << ".................................copy ok!" << endl;
        }



    }

}
