#include "function.h"
#include "EthFrmRcvPool.h"
#include "XmlConfig.h"
#include "ThreadFlags.h"
#include "FileLog.h"
extern EthFrmRcvPool * pEthRcvPool[2];
extern XmlConfig *xmlConf;
extern ThreadFlags *flags;
extern FileLog fileLog;
extern char feedbacklog[300];
void computeRoiAndSerialData(PARAMSTHREAD *para){
	int count = 0;
	int length = para->com[0].length;
	int nFramePerRcvBuf = para->com[0].nFramePerRcvBuf;

	int cnt=0;
	unsigned short *pt[BUFFER_NUM];
	short *reg[BUFFER_NUM];

    //bool ifwriteroi = true;

	bool ifstoreROI = xmlConf->getIfStoreRoi();
    bool ifstoreresimg = xmlConf->getIfStoreResultImage();
	unsigned int regNumber = xmlConf->getRegNumber();

	string roivalueStore = xmlConf->getRoiValueStorePath();
	int nRcvBuf = xmlConf->getnRcvBuf();
    unsigned long long int totalRcv = 0;
    bool ifMessageOut = false;
    int sizebuf = pEthRcvPool[0]->getSizeBuf();
    int step  = nFramePerRcvBuf*BUFFER_NUM;
    int cachecnt = 0;
    int protimes = 0;
    int totalprotimes_cache0 =regNumber/step;
    int totalprotimes_cache1 =totalprotimes_cache0 + 1;
   // cout <<totalprotimes_cache0 << " times " << totalprotimes_cache1 << endl;
    struct timeval start, end;
    long timing;

    while (flags->ifroiandserial)
	{

       if(flags->synccomputeroi1 && flags->synccomputeroi2){
          // if(((pEthRcvPool[0]->getidxRcvBuf()- pEthRcvPool[0]->getpRoi()+ nRcvBuf) % nRcvBuf) >0 ||
            //       ((pEthRcvPool[1]->getidxRcvBuf()- pEthRcvPool[1]->getpRoi()+ nRcvBuf) % nRcvBuf) >0){
            if(ifstoreresimg){
                if(((pEthRcvPool[0]->getidxRcvBufToProc() - pEthRcvPool[0]->getpRoi()+pEthRcvPool[0]->nRcvBuf) % (pEthRcvPool[0]->nRcvBuf)) &&
                        ((pEthRcvPool[1]->getidxRcvBufToProc() - pEthRcvPool[1]->getpRoi()+pEthRcvPool[1]->nRcvBuf) % (pEthRcvPool[1]->nRcvBuf))){

                       // gettimeofday(&start,NULL);
                        pt[0] = pEthRcvPool[0]->curBufToProc_proi();
                        pt[1] = pEthRcvPool[1]->curBufToProc_proi();
                        reg[0] = pEthRcvPool[0]->curBufIndexToProc_proi();
                        reg[1] = pEthRcvPool[1]->curBufIndexToProc_proi();
                       /* if(cachecnt && !protimes){
                            for(int i=0; i < nFramePerRcvBuf; i++){

                                    int n = cnt + i*BUFFER_NUM;
                                    //cout << "cnt - 1 : " << n << endl;
                                    //sprintf(feedbacklog, " -- regid:%d,num:%d. num%regnum=%d\n",reg[1][i],n,n%regNumber);
                                    //fileLog.logEthernetFrame(feedbacklog,11);
                                     computeROI(reg[1][i],pt[1]+i*length,para->com,n,regNumber);



                            }
                            //cachecnt = 0;
                            pEthRcvPool[0]->finishCurBufProc_proi();
                            pEthRcvPool[1]->finishCurBufProc_proi();
                            cnt += nFramePerRcvBuf;
                            protimes++;
                            continue;
                        }*/

                    // gettimeofday(&start,NULL);
                    //copyToDevice(sizebuf,para);

                    //#pragma omp parallel for
                    for(int i=0; i < nFramePerRcvBuf; i++){
                        for(int k=0;k<BUFFER_NUM;k++){
                            int n = cnt + k + i*BUFFER_NUM;
                            //string timep = getTime();
                            //if(ifstoreROI)
                            //cout << "cnt  " <<cachecnt << " : "<< n << endl;
                            //sprintf(feedbacklog, " -- regid:%d,num:%d. num%regnum=%d\n",reg[k][i],n,n%regNumber);
                            //fileLog.logEthernetFrame(feedbacklog,11);
                                computeROI(reg[k][i],pt[k]+i*length,para->com,n,regNumber);


                        }
                    }
                   //gettimeofday(&end,NULL);
                   // timing =(end.tv_sec -start.tv_sec)*1000000+(end.tv_usec -start.tv_usec);
                   // cout << "roi cost 2:  "<< timing  << " us"<< endl;

                    cnt += step;

                        flags->syncwriteres = true;
                         //for(int i = 0; i < 2; i++){
                             pEthRcvPool[0]->finishCurBufProc_proi();
                             pEthRcvPool[1]->finishCurBufProc_proi();
                             // pEthRcvPool[i]->finishCurBufProc();
                        // }
                            /* protimes++;
                             if((!cachecnt) && (protimes==totalprotimes_cache0)){
                                 bool flag = true;
                                 //cout <<" 1111111111************************ cachecnt: " <<cachecnt << " protimes: " << protimes << endl;
                                 //cout << "1: " << pEthRcvPool[0]->getidxRcvBuf() << " " << pEthRcvPool[0]->getidxRcvBufToProc() << "  " << pEthRcvPool[0]->getpRoi() << "  " << pEthRcvPool[0]->getBufHead() << " " << pEthRcvPool[0]->gettotalRcvBufToProc()<< endl;
                                 while(flag){
                                     //cout <<" 2222222222222222************************ cachecnt: " <<cachecnt << " protimes: " << protimes << endl;
                                     if((pEthRcvPool[0]->getidxRcvBufToProc() - pEthRcvPool[0]->getpRoi()+pEthRcvPool[0]->nRcvBuf) % (pEthRcvPool[0]->nRcvBuf)){
                                         pt[0] = pEthRcvPool[0]->curBufToProc_proi();
                                         reg[0] = pEthRcvPool[0]->curBufIndexToProc_proi();
                                         for(int i=0; i < nFramePerRcvBuf; i++){

                                                 int n = cnt + i*BUFFER_NUM;
                                                  //cout << "cnt - 0 : " << n << endl;
                                                 //sprintf(feedbacklog, " -- regid:%d,num:%d. num%regnum=%d\n",reg[0][i],n,n%regNumber);
                                                 //fileLog.logEthernetFrame(feedbacklog,11);
                                                  computeROI(reg[0][i],pt[0]+i*length,para->com,n,regNumber);



                                         }
                                         cachecnt = 1;
                                         cnt += nFramePerRcvBuf;
                                         protimes = 0;

                                        // cout <<" 333333333333333333************************ cachecnt: " <<cachecnt << " protimes: " << protimes << endl;
                                         flag = false;
                                     }

                                 }

                             }
                             if(protimes == totalprotimes_cache1){
                                 protimes = 0;
                                 cachecnt = 0;
                             }*/

                   // cout <<" --------------------------- cachecnt: " <<cachecnt << " protimes: " << protimes << endl;
                    //cout << "1: " << pEthRcvPool[0]->getidxRcvBuf() << " " << pEthRcvPool[0]->getidxRcvBufToProc() << "  " << pEthRcvPool[0]->getpRoi() << "  " << pEthRcvPool[0]->getBufHead() << " " << pEthRcvPool[0]->gettotalRcvBufToProc()<< endl;

                   // cout << "2: " << pEthRcvPool[1]->getidxRcvBuf() << " " << pEthRcvPool[1]->getidxRcvBufToProc() << "  " << pEthRcvPool[1]->getpRoi() << "  " << pEthRcvPool[1]->getBufHead() << " " << pEthRcvPool[1]->gettotalRcvBufToProc()<< endl;
                }
            }
            else{
                if(((pEthRcvPool[0]->getidxRcvBufToProc() - pEthRcvPool[0]->getpRoi()+pEthRcvPool[0]->nRcvBuf) % (pEthRcvPool[0]->nRcvBuf)) &&
                        ((pEthRcvPool[1]->getidxRcvBufToProc() - pEthRcvPool[1]->getpRoi()+pEthRcvPool[1]->nRcvBuf) % (pEthRcvPool[1]->nRcvBuf))){


                        reg[0] = pEthRcvPool[0]->curBufIndexToProc();
                        reg[1] = pEthRcvPool[1]->curBufIndexToProc();
                        pt[0] = pEthRcvPool[0]->curBufToProc();
                        pt[1] = pEthRcvPool[1]->curBufToProc();
                       /* if(cachecnt && !protimes){
                            for(int i=0; i < nFramePerRcvBuf; i++){

                                    int n = cnt + i*BUFFER_NUM;
                                    //cout << "cnt - 1 : " << n << endl;
                                    //sprintf(feedbacklog, " -- regid:%d,num:%d. num%regnum=%d\n",reg[1][i],n,n%regNumber);
                                    //fileLog.logEthernetFrame(feedbacklog,11);
                                     computeROI(reg[1][i],pt[1]+i*length,para->com,n,regNumber);



                            }
                            //cachecnt = 0;
                            pEthRcvPool[0]->finishCurBufProc();
                            pEthRcvPool[1]->finishCurBufProc();
                            pEthRcvPool[0]->finishCurBufProc_proi();
                            pEthRcvPool[1]->finishCurBufProc_proi();
                            cnt += nFramePerRcvBuf;
                            protimes++;
                            continue;
                        }*/

                    // gettimeofday(&start,NULL);
                    //copyToDevice(sizebuf,para);

                    //#pragma omp parallel for
                    for(int i=0; i < nFramePerRcvBuf; i++){
                        for(int k=0;k<BUFFER_NUM;k++){
                            int n = cnt + k + i*BUFFER_NUM;
                            //string timep = getTime();
                            //if(ifstoreROI)
                            //cout << "cnt: " << cnt << endl;
                            computeROI(reg[k][i],pt[k]+i*length,para->com,n,regNumber);


                        }
                    }


                    cnt += step;


                             pEthRcvPool[0]->finishCurBufProc();
                             pEthRcvPool[1]->finishCurBufProc();
                             pEthRcvPool[0]->finishCurBufProc_proi();
                             pEthRcvPool[1]->finishCurBufProc_proi();



                            /* protimes++;
                             if((!cachecnt) && (protimes==totalprotimes_cache0)){
                                 bool flag = true;
                                 //cout <<" 1111111111************************ cachecnt: " <<cachecnt << " protimes: " << protimes << endl;
                                 //cout << "1: " << pEthRcvPool[0]->getidxRcvBuf() << " " << pEthRcvPool[0]->getidxRcvBufToProc() << "  " << pEthRcvPool[0]->getpRoi() << "  " << pEthRcvPool[0]->getBufHead() << " " << pEthRcvPool[0]->gettotalRcvBufToProc()<< endl;
                                 while(flag){
                                     //cout <<" 2222222222222222************************ cachecnt: " <<cachecnt << " protimes: " << protimes << endl;
                                     if((pEthRcvPool[0]->getidxRcvBufToProc() - pEthRcvPool[0]->getpRoi()+pEthRcvPool[0]->nRcvBuf) % (pEthRcvPool[0]->nRcvBuf)){
                                         pt[0] = pEthRcvPool[0]->curBufToProc();
                                         reg[0] = pEthRcvPool[0]->curBufIndexToProc();
                                         for(int i=0; i < nFramePerRcvBuf; i++){

                                                 int n = cnt + i*BUFFER_NUM;
                                                  //cout << "cnt - 0 : " << n << endl;
                                                 //sprintf(feedbacklog, " -- regid:%d,num:%d. num%regnum=%d\n",reg[0][i],n,n%regNumber);
                                                 //fileLog.logEthernetFrame(feedbacklog,11);
                                                  computeROI(reg[0][i],pt[0]+i*length,para->com,n,regNumber);



                                         }
                                         cachecnt = 1;
                                         cnt += nFramePerRcvBuf;
                                         protimes = 0;

                                        // cout <<" 333333333333333333************************ cachecnt: " <<cachecnt << " protimes: " << protimes << endl;
                                         flag = false;
                                     }

                                 }

                             }
                             if(protimes == totalprotimes_cache1){
                                 protimes = 0;
                                 cachecnt = 0;
                             }*/


                             if (totalRcv - ((totalRcv >> 15) << 15) == 0)
                             {

                                 ifMessageOut = true;
                             }
                             ++totalRcv;



                             if (ifMessageOut)
                             {
                                 ifMessageOut = false;
                                 std::cout << "------------------------------------ totalRcvBufToProc 1  :"<< pEthRcvPool[0]->totalRcvBufToProc<< std::endl;
                                 std::cout << "------------------------------------ totalRcvBufToProc 2  :" << pEthRcvPool[1]->totalRcvBufToProc<< std::endl;

                             }
                       // }


                }

            }


          // }
           /*if(!pEthRcvPool[0]->gettotalRcvBufToProc()  && (!pEthRcvPool[1]->gettotalRcvBufToProc())){
               ifwriteroi = false;
               computeroiflags2 = false;
               computeroiflags1 = false;
               cout << "computeRoiAndSerialData end!" << endl;
           }*/
       }

	}
	//sleep(1);
	//while(!writeroistopflags && writeroiflags){
	if(ifstoreROI)
		writeROI(roivalueStore,regNumber);
	//writeroistopflags = true;
	//}




	//std:cout << ".................................copy ok!" << endl;


}
