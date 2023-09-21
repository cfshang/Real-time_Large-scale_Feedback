#include "function.h"
#include "EthFrmRcvPool.h"
#include "ThreadCreate.h"
#include "XmlConfig.h"
#include "ThreadFlags.h"
using namespace std;

extern EthFrmRcvPool * pEthRcvPool[2];
extern POSITION ptn;
unsigned int regNumber;
extern XmlConfig *xmlConf;
extern ThreadFlags *flags;
extern TIF tiff[GPU_MAX];

const char *datapath[2];

inline int set_cpu(int cpu_id){
    cpu_set_t mask;
    CPU_ZERO(&mask);
    CPU_SET(cpu_id,&mask);
    if(pthread_setaffinity_np(pthread_self(),sizeof(mask),&mask) == -1){
        cout << "The productThread thread could not set cpu affinity ." << endl;
        return -1;
    }
    return 0;
}
void *storedata(void *arg){
    /*cpu_set_t mask;
    int cpu_id = 6;
    CPU_ZERO(&mask);
    CPU_SET(cpu_id,&mask);
    if(sched_setaffinity(0,sizeof(mask),&mask) == -1){ //this bind process not thread
        cout << "The consumerFramestoGPU thread could not set cpu affinity ." << endl;
    }*/
    if(set_cpu(BIND_CORE_STORE1)){
        cout << "The productThread-1 thread could not set cpu affinity ." << endl;
    }
	COMMON *com = (COMMON *)arg;
	unsigned short *buffhead;
	short *reg;
	EthFrmRcvPool *ptr = pEthRcvPool[0];
	int cnt = 0;
	char outputfile[300];
	unsigned long long int totalRcv = 0;
	bool ifMessageOut = false;
    //#pragma omp parallel num_threads(6)

   // bool ifstop = false;
    while(flags->ifstore1){

        if(flags->syncwriteres){
            if(((ptr->getpRoi() - ptr->getBufHead()+ptr->getnRcvBuf()) % (ptr->getnRcvBuf()))  && ptr->gettotalRcvBufToProc()){
               // cout << "1: "<< ptr->getidxRcvBufToProc() << "  " << ptr->getpRoi() << "  " << ptr->getBufHead() << " " << ptr->gettotalRcvBufToProc()<< endl;
                //gettimeofday(&start,NULL);
                struct timeval start, end;
                long timing;
                //gettimeofday(&start,NULL);
                reg = ptr->curBufIndexToProc();
                buffhead = ptr->curBufToProc();
                //#pragma omp parallel for num_threads(2) proc_bind(spread)
                for(int i=0; i< com[0].nFramePerRcvBuf;i++){
                    int n = cnt + i * BUFFER_NUM;

                    sprintf(outputfile,"%s_%d_%d.tif",datapath[0],n,reg[i]);
                    //
                    int res = writeTIF(outputfile,&tiff[0],buffhead+i*com[0].length);
                   //
                    if(!res){
                        cout << "The Image write1 error!"<< n <<endl;
                        exit(-1);
                    }

                }
               /* sprintf(outputfile,"%s_%d_%d",datapath[0],cnt,reg[0]);
                int out = open(outputfile,O_CREAT | O_TRUNC | O_WRONLY , S_IRWXU | S_IRWXG | S_IRWXO);
                //memcpy(&ptif[1][TIFF_HEADER],&sdata[0],tifdatasize[1]);
                write(out, buffhead, ptr->getSizeBuf()*sizeof (unsigned short));
                close(out);*/
                //gettimeofday(&end,NULL);
                //timing =(end.tv_sec -start.tv_sec)*1000+(end.tv_usec -start.tv_usec)/1000;
                //cout << "write 5 images cost  "<< timing  << " ms"<< endl;

                cnt += com[0].nFramePerRcvBuf*BUFFER_NUM;

                ptr->finishCurBufProc();
                //cout  << "*************************************************************************************************************************" << endl;
                if (totalRcv - ((totalRcv >> 3) << 3) == 0)
                {

                    ifMessageOut = true;
                }
                ++totalRcv;



                if (ifMessageOut)
                {
                    ifMessageOut = false;
                    std::cout << "   totalStoreBufs:" << totalRcv << ", totalRcvBufToProc 1  :" << ptr->totalRcvBufToProc <<std::endl;
                    fflush(stdout);
                }

                //gettimeofday(&stop,NULL);
                //diff = (stop.tv_sec-start.tv_sec)*1000+(stop.tv_usec-start.tv_usec)/1000;
               // cout << "consumerstore 1 computed : " << cnt  << "    ----> " << diff << " ms. "<< endl;
            }
           /* if(!ptr->gettotalRcvBufToProc()){
                ifstop = true;
            }*/
        }



	}
}

void *storedata2(void *arg){
    /*cpu_set_t mask;
    int cpu_id = 7;
    CPU_ZERO(&mask);
    CPU_SET(cpu_id,&mask);
    if(sched_setaffinity(0,sizeof(mask),&mask) == -1){
        cout << "The consumerFramestoGPU thread could not set cpu affinity ." << endl;
    }*/
    if(set_cpu(BIND_CORE_STORE2)){
        cout << "The productThread-1 thread could not set cpu affinity ." << endl;
    }
	COMMON *com = (COMMON *)arg;
	unsigned short *buffhead;
	short *reg;
	EthFrmRcvPool *ptr = pEthRcvPool[1];
	int cnt = 1;
	char outputfile[300];
	unsigned long long int totalRcv = 0;
	bool ifMessageOut = false;
    struct timeval start, end;
    long timing;
    while(flags->ifstore2){

        //cout << "strore start2" << endl;
        //if((writeresflags) && ((ptr->getidxRcvBufToProc() - ptr->getBufHead()+ptr->nRcvBuf) % (ptr->nRcvBuf)) && ptr->totalRcvBufToProc){
        if(flags->syncwriteres){
            if(((ptr->getpRoi() - ptr->getBufHead()+ptr->getnRcvBuf()) % (ptr->getnRcvBuf()))  && ptr->gettotalRcvBufToProc()){
                //gettimeofday(&start,NULL);
                reg = ptr->curBufIndexToProc();
                buffhead = ptr->curBufToProc();
                //#pragma omp parallel for num_threads(2) proc_bind(spread)
                for(int i=0; i< com[1].nFramePerRcvBuf;i++){
                    int n = cnt + i * BUFFER_NUM;

                    sprintf(outputfile,"%s_%d_%d.tif",datapath[1],n,reg[i]);
                    int res = writeTIF(outputfile,&tiff[1],buffhead+i*com[1].length);
                    if(!res){
                        cout << "The Image write2 error!"<< n <<endl;
                        exit(-1);
                    }

                }
                cnt += com[1].nFramePerRcvBuf*BUFFER_NUM;
                ptr->finishCurBufProc();
                //gettimeofday(&end,NULL);
                //timing =(end.tv_sec -start.tv_sec)*1000000+(end.tv_usec -start.tv_usec);
                 //cout << "write cost 1:  "<< timing  << " us"<< endl;
                if (totalRcv - ((totalRcv >> 3) << 3) == 0)
                {

                    ifMessageOut = true;
                }
                ++totalRcv;



                if (ifMessageOut)
                {
                    ifMessageOut = false;
                    std::cout << "   totalStoreBufs:" << totalRcv << ", totalRcvBufToProc 2  :" << ptr->totalRcvBufToProc<<std::endl;
                    fflush(stdout);
                }
                // cout << "2: "<< ptr->getidxRcvBufToProc() << "  " << ptr->getpRoi() << "  " << ptr->getBufHead() << " " << ptr->gettotalRcvBufToProc()<< endl;

            }
           /* if(!ptr->gettotalRcvBufToProc()){
                ifstop = true;
            }*/
        }

    }
}

/*** the thread of result data store **/
void startConsumerThread(const char* datastore,const char* datastore2,COMMON *com){
	/*unsigned short *pt[THREAD_NUM];
	  short *reg[THREAD_NUM];
	  EthFrmRcvPool * ptr[2];
	  ptr[0] = pEthRcvPool[0];
	  ptr[1] = pEthRcvPool[1];

	  while(!while_do1){
	  reg[0] = pEthRcvPool[0]->curBufIndexToProc();
	  reg[1] = pEthRcvPool[1]->curBufIndexToProc();
	  pt[0] = pEthRcvPool[0]->curBufToProc();
	  pt[1] = pEthRcvPool[1]->curBufToProc();

	  if((!first) && (((ptr[0]->getidxRcvBufToProc() - ptr[0]->getBufHead()+ptr[0]->nRcvBuf) % (ptr[0]->nRcvBuf))  )){
	  if(((ptr[1]->getidxRcvBufToProc() - ptr[1]->getBufHead()+ptr[1]->nRcvBuf) % (ptr[1]->nRcvBuf))){

	  }
	  else{

	  }

	  }
	  }*/
    //signal(SIGINT,  sigproc_send1);
   // signal(SIGTERM, sigproc_send1);
    regNumber = xmlConf->getRegNumber();
    datapath[0] = datastore;
    datapath[1] = datastore2;
	pthread_t my_thread[2];

	ThreadCreate::pthreadCreate(&my_thread[0], NULL, storedata,(void*)com,__FILE__, __LINE__);
	ThreadCreate::pthreadCreate(&my_thread[1], NULL, storedata2,(void*)com,__FILE__, __LINE__);


	for(int i=0; i<2; i++){
		pthread_join(my_thread[i], NULL);

        //sleep(1);
	}


}
