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
void buffProcessingReference(PARAMSTHREAD *para){
    int count = 0;
    int length = para->com[0].length;
    int nFramePerRcvBuf = para->com[0].nFramePerRcvBuf;
    char outputfile[300];
    //char *filename = "CASIA";
    int cnt=0;
    unsigned short *pt[BUFFER_NUM];
    short *reg[BUFFER_NUM];
    //omp_set_num_threads(exeNumGPU);

    //bool is_stop_model = false;
    bool ifstoreReference = xmlConf->getIfStoreReference();
    //bool ifstoreROI = xmlConf->getIfStoreRoi();
    unsigned int regNumber = xmlConf->getRegNumber();
    unsigned int referenceNumber = xmlConf->getReferenceNumber();
    unsigned int numReferencePerETH = xmlConf->getReferenceNumber()/2;
    string referenceStorePath = xmlConf->getReferenceStorePath();
    //string roivalueStore = xmlConf->getRoiValueStorePath();
    //int nRcvBuf = xmlConf->getnRcvBuf();
    while (flags->ifdealReference)
    {
        if(pEthRcvPool[0]->gettotalRcvBufToProc() && pEthRcvPool[1]->gettotalRcvBufToProc()){
            reg[0] = pEthRcvPool[0]->curBufIndexToProc_refer();
            reg[1] = pEthRcvPool[1]->curBufIndexToProc_refer();
            pt[0] = pEthRcvPool[0]->curBufToProc_refer();
            pt[1] = pEthRcvPool[1]->curBufToProc_refer();
            int sizebuf = pEthRcvPool[0]->getSizeBuf();

            int modInOnePool = numReferencePerETH;

           // if(ifdealModel && count < modInOnePool){
                int ntmp;
                if(ifstoreReference){
                   // struct timeval start, end;
                   // long timing;
                   // gettimeofday(&start,NULL);
                    for(int i=0; i < nFramePerRcvBuf; i++){
                        for(int k=0;k<BUFFER_NUM;k++){
                            ntmp = cnt + k + i*BUFFER_NUM;
                            //string timep = getTime();
                            if(ntmp < referenceNumber){
                                sprintf(outputfile,"%s_%d_%d.tif",referenceStorePath.c_str(),ntmp,reg[k][i]);
                                int res = writeTIF(outputfile,&tiff[0],pt[k]+i*length);
                                if(!res){
                                    cout << "The ModelImage write error!"<< ntmp <<endl;
                                    exit(-1);
                                }
                            }
                        }
                    }
                   // gettimeofday(&end,NULL);
                   // timing =(end.tv_sec -start.tv_sec)*1000+(end.tv_usec -start.tv_usec)/1000;
                   // cout << "write 5 images cost  "<< timing  << " ms"<< endl;
                }
                if(ntmp < referenceNumber){
                    // cout << "copy to data model" << endl;
                    prepareReference(count,sizebuf,para,referenceNumber,regNumber);
                }
                int rangeEnd = (count + nFramePerRcvBuf)*2 - 1;
                if(rangeEnd < referenceNumber)
                    cout << " Prepare model number : "  << count*2 << " ~~ "<< rangeEnd << endl;
                else
                    cout << " Prepare model number : "  << count*2 << " ~~ "<< referenceNumber-1 << endl;

                count += nFramePerRcvBuf;
                cnt += (nFramePerRcvBuf*BUFFER_NUM);

                for(int i = 0; i < 2; i++){
                    pEthRcvPool[i]->finishCurBufProc();
                }

                if(count >= modInOnePool){
                    for(int i = 0; i < 2; i++){
                        pEthRcvPool[i]->setIdxVar();
                        pEthRcvPool[i]->changeDealStaVar();
                    }
                    usleep(1000);

                    flags->ifdealReference = false;
                    cnt = 0;
                    flags->syncifdealPic1 = true;
                    flags->syncifdealPic2 = true;

                    cout << "Pictrue data start !" << endl;
                }


        }


    }
}
