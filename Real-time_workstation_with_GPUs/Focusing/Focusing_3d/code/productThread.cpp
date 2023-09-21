#include <stdlib.h>
#include <unistd.h>
#include <netinet/ip.h>
#include <netinet/if_ether.h>
#include <mutex>
#include "FileLog.h"
#include "Printglobal.h"
#include "EthFrmRcvPool.h"
#include "ThreadCreate.h"
#include <vector>
#include "function.h"
#include <signal.h>
#include <sched.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <errno.h>
#include <sys/time.h>
#include <time.h>
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <assert.h>
#include <iostream>
#include "ixcap_lib.h"

#define PACKETHEADER 42
#define PACKETCOUNTER 4
#define PICTURECOUNTER 2
#define HEADER (PACKETCOUNTER+PACKETHEADER+PICTURECOUNTER*2)
extern EthFrmRcvPool * pEthRcvPool[2];
extern POSITION ptn;
//extern COMMON com[GPU_MAX];
extern bool flags;

extern int do_shutdown;
extern bool is_stop;
extern bool first;

const int BATCH_SIZE = 512;
ixcap_dev* ixcapdev[2];
const char *method = "EthFrmRcvPool::init";
u_int8_t wait_for_packet = 1;
unsigned long long numPkts = 0, numBytes = 0;

unsigned int getIndex(u_char *packetIdBegin)
{
	unsigned int index =0;
	index += ((unsigned int)(packetIdBegin[0]))<<24;
	index += ((unsigned int)(packetIdBegin[1]))<<16;
	index += ((unsigned int)(packetIdBegin[2]))<<8;
	index += (unsigned int)(packetIdBegin[3]);
	return index;

}
unsigned int getPicIndex(u_char *packetIdBegin)
{
	unsigned int index =0;
	index += ((unsigned int)(packetIdBegin[0]))<<8;
	index += ((unsigned int)(packetIdBegin[1]));
	return index;

}
void transformChar2Short(u_char *src,unsigned short *dest,int length)
{
	//omp_set_num_threads(8);

	//#pragma omp parallel for 
	int count = 0;
	int start = ptn.x_start*2;
	int end  = ptn.x_end*2;
	int offset = length / 2;
	//cout << offset << endl;
	for(int i = start; i <= end; i +=2){
		unsigned short high =((unsigned short)(src[i+1])) << 8;
		unsigned short low = ((unsigned short)(src[i]));	
		dest[count] = high + low;
		// fdest[count] = dest[count];
		count++;
	}
	//cout << count << endl;
	for(int i = start+offset; i <= (end+offset); i+=2){
		unsigned short high =((unsigned short)(src[i+1])) << 8;
		unsigned short low = ((unsigned short)(src[i]));
		dest[count] = high + low;
		//  fdest[count] = dest[count];
		count++;
	}


}
void transformChar2ShortandFloat(u_char *src,unsigned short *dest,float *fdest,int length)
{
	//omp_set_num_threads(8);

	//#pragma omp parallel for
	int count = 0;
	int start = ptn.x_start*2;
	int end  = ptn.x_end*2;
	int offset = length / 2;
	//cout << offset << endl;
	for(int i = start; i <= end; i +=2){
		unsigned short high =((unsigned short)(src[i+1])) << 8;
		unsigned short low = ((unsigned short)(src[i]));
		// float fhigh =((unsigned short)(src[i+1])) << 8;
		// float flow = ((unsigned short)(src[i]));
		dest[count] = high + low;
		fdest[count] = high + low;
		count++;
	}
	//cout << count << endl;
	for(int i = start+offset; i <= (end+offset); i+=2){
		unsigned short high =((unsigned short)(src[i+1])) << 8;
		unsigned short low = ((unsigned short)(src[i]));
		dest[count] = high + low;
		//float fhigh =((unsigned short)(src[i+1])) << 8;
		// float flow = ((unsigned short)(src[i]));
		fdest[count] = high + low;
		count++;
	}


}
void transformChar2Float(unsigned short *src,float *dest,int length)
{
	//omp_set_num_threads(8);

	//#pragma omp parallel for
	int size = length / (sizeof(unsigned short));
	for(int i=0; i< size; i++){
		dest[i] = (float)src[i];
	}


}
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
void * productThread1(void *arg){
    /*cpu_set_t mask;
    int cpu_id = 4;
    CPU_ZERO(&mask);
    CPU_SET(cpu_id,&mask);
    if(sched_setaffinity(0,sizeof(mask),&mask) == -1){
        cout << "The consumerFramestoGPU thread could not set cpu affinity ." << endl;
    }*/
    if(set_cpu(5)){
        cout << "The productThread-1 thread could not set cpu affinity ." << endl;
    }
	COMMON *com = (COMMON *)arg;
	std::cout << "Receive data 1 start !" << endl;
	//cout << HEADER << endl;
	EthFrmRcvPool *ptr = pEthRcvPool[0];
	//std::size_t idxRcvBuf = 0;
	//std::size_t idxFrameInRcvBuf = 0;
	bool ifMessageOut = false;
	unsigned int idxRcvEthFrmPool = 0;
	//unsigned long long int totalRcv = 0;
	unsigned int packetId = 0;
	unsigned int pictureId = 0;
	unsigned int prePictureId = -1;
	unsigned int prePacketId = -1;
	unsigned int regId = -1;
	bool first = true;
	//unsigned int packetCount = 0;
    ixcap_pkt_buf* bufs[BATCH_SIZE];
    //int frameIndex = 0;
    unsigned int z = -1;
    int bufferoffset = com[1].width * 2;
    int nFramesInRcvBufShort = ptr->nFramesInRcvBuf * com[1].height / 2;
    int picCount = 0;
    bool picCountFirst = true;
    struct timeval timingstart, timingend;
    long timing;
    bool iftimeCounterFirst = true;
    while(!do_shutdown) {
        if (ptr->totalRcvBufToProc < ptr->nRcvBuf)
        {

            /**** packet lens = 8192*/
            uint32_t num_rx = ixcap_recv_batch(ixcapdev[0], 0, bufs, BATCH_SIZE);

                        //u_char *pkt_data = pfring_zc_pkt_buff_data(buffers[0], zq[0]);
            unsigned char* pkt_data;
            if(num_rx > 0)
            {
                 iftimeCounterFirst = true;
                 for(uint32_t i = 0; i < num_rx; i++)
                 {
                  pkt_data = (unsigned char*)ixcap_get_pkt_data(bufs[i]);


                packetId = getIndex(pkt_data+PACKETHEADER);
				pictureId = getPicIndex(pkt_data+PACKETHEADER+PACKETCOUNTER);
				regId = getPicIndex(pkt_data+PACKETHEADER+PACKETCOUNTER+PICTURECOUNTER);
				//cout << regId << endl;
                if(regId == 0 || regId == 10 || regId == 22){
				if(first){
					first = false;
					prePacketId = packetId - 1;
					prePictureId = pictureId - 1;
					gettimeofday(&(ptr->start),NULL);
				}

				// || pictureId != (prePictureId + 1)
				if(packetId != (prePacketId+1) ){
					gettimeofday(&(ptr->end),NULL);
					unsigned long long lost = packetId - prePacketId;
					ptr->lostPacketNum += lost;
					unsigned long long diff = (ptr->end.tv_sec - ptr->start.tv_sec)*1000+(ptr->end.tv_usec - ptr->start.tv_usec)/1000;
					//std::cout <<"The pre and index is " << prePacketId <<" "<<packetId<< "the buffer len is "<< buffers[0]->len << endl;
					printf("The preID is %d, the curID is %d, lost %d packet(total count is %d) in picture %d (prePictureId is %d )when %d.\n",prePacketId,packetId,lost,ptr->packetCount,pictureId,prePictureId,diff);
					//ptr->do_shutdown = 1;
				}


				prePacketId = packetId;
				int line = ptr->packetCount * 2;
				if(ptr->packetCount == 1023){
					//first = true;
					//prePacketId = -1;
					prePictureId = pictureId;
					ptr->packetCount = 0;
					//cout  << "______________the regId is " << regId <<ptr->frameIndex <<endl;
					ptr->vRcvBufIndex[ptr->idxRcvBuf][ptr->frameIndex] = regId;
					ptr->frameIndex ++;
					//ptr->vRcvBufIndex[idxRcvBuf][frameIndex] = 100;
					if(ptr->frameIndex == ptr->nFramesInRcvBuf)
						ptr->frameIndex = 0;
					ptr->picCount ++;
					//cout << "pic : " << ptr->picCount << endl;
				}



                if(line >= ptn.y_start && line <=ptn.y_end){
					int frameIndex = ptr->idxFrameInRcvBuf*bufferoffset;
					//cout  << "!!!!!!!!!!!!!!!!!!!!!!!copy !!" << endl;
					unsigned short *destpoint = &(ptr->vRcvBuf[ptr->idxRcvBuf][frameIndex]);
                //	float *fdestpoint = &(ptr->vRcvBufFloat[ptr->idxRcvBuf][frameIndex]);
					u_char *srcpoint = pkt_data+HEADER;
                    int length = ixcap_get_pkt_size(bufs[i]) - HEADER;
					//int length = ptr->sizeFrame;
                    transformChar2Short(srcpoint,destpoint,length);
                    //transformChar2ShortandFloat(srcpoint,destpoint,fdestpoint,length);
					// transformChar2Float(destpoint,fdestpoint,length);
					//cout << length << endl;
					ptr->idxFrameInRcvBuf++;
					if (ptr->idxFrameInRcvBuf == nFramesInRcvBufShort)
					{
						ptr->idxFrameInRcvBuf = 0;
						ptr->idxRcvBuf++;

						ptr->poolMutex.lock();
						ptr->totalRcvBufToProc++;

						ptr->poolMutex.unlock();

						if (ptr->totalRcv - ((ptr->totalRcv >> 3) << 3) == 0)
						{

							ifMessageOut = true;
						}
						++(ptr->totalRcv);

						if (ptr->idxRcvBuf == ptr->nRcvBuf)
							ptr->idxRcvBuf = 0;

					}

					if (ifMessageOut)
					{
						ifMessageOut = false;
						std::cout << "------totalRcvBufs1:" << ptr->totalRcv<< ", -------totalRcvBufToProc1:" << ptr->totalRcvBufToProc << std::endl;
						//std::cout << "totalRcvBytes:" << totalRcv * ptr->sizeBuf
						//<< std::endl;
					}
					//ptr->recvEthFramesSize[idxRcvEthFrmPool] = n;
					//cout << line << endl;
                }

                ptr->packetCount++;
                }
                ixcap_free_pkt_buf(bufs[i]);
                }
            }
            else{
                           if(iftimeCounterFirst){
                               iftimeCounterFirst = false;
                               gettimeofday(&timingstart,NULL);

                           }
                           gettimeofday(&timingend,NULL);
                           //timing = timingend.tv_sec - timingstart.tv_sec;
                           timing =(timingend.tv_sec -timingstart.tv_sec)*1000+(timingend.tv_usec -timingstart.tv_usec)/1000;
                           //cout << "timing " << timing <<endl;
                           if(timing > 100){


                                first = true;
                               //system("echo 1 > /proc/sys/vm/drop_caches");


                           }
                           if( timing > 4*60*1000){
                              is_stop = true;
                              do_shutdown = 1;
                           }
                       }

		}
		else
		{
			const char *methods = "EthFrmRcvPool::init";
			Printglobal::doPrintErrorHints(methods,
					"warning : mac recv pool is filled.(If you see this warning ,it means"
					" BUFFERNUM should be modified and the program should "
					"be recompiled,or you may lose some frames)",
					__FILE__, __LINE__);
			usleep(1000);
		}

		//ptr->numPkts++;
		//ptr->numBytes += buffers[0]->len + 24; /* 8 Preamble + 4 CRC + 12 IFG*/
	}

}
void * productThread2(void *arg){
    /*cpu_set_t mask;
    int cpu_id = 5;
    CPU_ZERO(&mask);
    CPU_SET(cpu_id,&mask);
    if(sched_setaffinity(0,sizeof(mask),&mask) == -1){
        cout << "The consumerFramestoGPU thread could not set cpu affinity ." << endl;
    }*/
    if(set_cpu(6)){
        cout << "The productThread-2 thread could not set cpu affinity ." << endl;
    }
	COMMON *com = (COMMON *)arg;
	std::cout << "Receive data 2 start !" << endl;
	//cout << HEADER << endl;
	EthFrmRcvPool *ptr = pEthRcvPool[1];
	//std::size_t idxRcvBuf = 0;
	//std::size_t idxFrameInRcvBuf = 0;
	bool ifMessageOut = false;
	unsigned int idxRcvEthFrmPool = 0;
	//unsigned long long int totalRcv = 0;
	unsigned int packetId = 0;
	unsigned int pictureId = 0;
	unsigned int prePictureId = -1;
	unsigned int prePacketId = -1;
	unsigned int regId = -1;
	bool first = true;
    ixcap_pkt_buf* bufs[BATCH_SIZE];
	//int frameIndex = 0;
	unsigned int z = -1;
	int bufferoffset = com[1].width * 2;
	int nFramesInRcvBufShort = ptr->nFramesInRcvBuf * com[1].height / 2;
	int picCount = 0;
	bool picCountFirst = true;
    struct timeval timingstart, timingend;
    long timing;
    bool iftimeCounterFirst = true;
	while(!do_shutdown) {
		if (ptr->totalRcvBufToProc < ptr->nRcvBuf)
		{

			/**** packet lens = 8192*/
            uint32_t num_rx = ixcap_recv_batch(ixcapdev[1], 0, bufs, BATCH_SIZE);

                        //u_char *pkt_data = pfring_zc_pkt_buff_data(buffers[0], zq[0]);
            unsigned char* pkt_data;

            if(num_rx > 0)
            {
                 iftimeCounterFirst = true;
                 for(uint32_t i = 0; i < num_rx; i++)
                 {
                  pkt_data = (unsigned char*)ixcap_get_pkt_data(bufs[i]);


                packetId = getIndex(pkt_data+PACKETHEADER);
				pictureId = getPicIndex(pkt_data+PACKETHEADER+PACKETCOUNTER);
				regId = getPicIndex(pkt_data+PACKETHEADER+PACKETCOUNTER+PICTURECOUNTER);
				//cout  << buffers[1]->len << " -- " << packetCount++ << endl;
                if(regId == 0 || regId == 10 || regId == 22){
				if(first){
					first = false;
					prePacketId = packetId - 1;
					prePictureId = pictureId - 1;
					gettimeofday(&(ptr->start),NULL);
				}

				if(packetId != (prePacketId+1) ){
					gettimeofday(&(ptr->end),NULL);
					unsigned long long lost = packetId - prePacketId;
					ptr->lostPacketNum += lost;
					unsigned long long diff = (ptr->end.tv_sec - ptr->start.tv_sec)*1000+(ptr->end.tv_usec - ptr->start.tv_usec)/1000;
					//std::cout <<"The pre and index is " << prePacketId <<" "<<packetId<< "the buffer len is "<< buffers[1]->len << endl;
					printf("The preID is %d, the curID is %d, lost %d packet(total count is %d) in picture %d (prePictureId is %d )when %d.\n",prePacketId,packetId,lost,ptr->packetCount,pictureId,prePictureId,diff);
					//ptr->do_shutdown = 1;
				}


				prePacketId = packetId;
				int line = ptr->packetCount * 2;
				if(ptr->packetCount == 1023){
					//first = true;
					//prePacketId = -1;
					prePictureId = pictureId;
					ptr->packetCount = 0;
					//cout  << "the regId is " << regId << endl;
					ptr->vRcvBufIndex[ptr->idxRcvBuf][ptr->frameIndex] = regId;
					ptr->frameIndex ++;
					//ptr->vRcvBufIndex[idxRcvBuf][frameIndex] = 100;
					if(ptr->frameIndex == ptr->nFramesInRcvBuf)
						ptr->frameIndex = 0;
					ptr->picCount ++;
					//cout << "pic1 : " << ptr->picCount << endl;
				}
				//assert(buffers[1]->len == ptr->sizeFrame);
				//memcpy(&(ptr->vRcvBuf[idxRcvBuf][idxFrameInRcvBuf*ptr->sizeFrame]),(char*)(pkt_data+HEADER),ptr->sizeFrame);
				//cout << buffers[1]->len <<endl;


                if(line >= ptn.y_start && line <=ptn.y_end){
					//cout  << "!!!!!!!!!!!!!!!!!!!!!!!copy !!" << endl;
					int frameIndex = ptr->idxFrameInRcvBuf*bufferoffset;
					unsigned short *destpoint = &(ptr->vRcvBuf[ptr->idxRcvBuf][frameIndex]);
                    //float *fdestpoint = &(ptr->vRcvBufFloat[ptr->idxRcvBuf][frameIndex]);
					u_char *srcpoint = pkt_data+HEADER;
                    int length = ixcap_get_pkt_size(bufs[i]) - HEADER;
					//int length = ptr->sizeFrame;
                    transformChar2Short(srcpoint,destpoint,length);
                    //transformChar2ShortandFloat(srcpoint,destpoint,fdestpoint,length);
					// transformChar2Float(destpoint,fdestpoint,length);
					//cout << length << endl;
					ptr->idxFrameInRcvBuf++;
					if (ptr->idxFrameInRcvBuf == nFramesInRcvBufShort)
					{
						ptr->idxFrameInRcvBuf = 0;
						ptr->idxRcvBuf++;

						ptr->poolMutex.lock();
						ptr->totalRcvBufToProc++;
						ptr->poolMutex.unlock();

						if (ptr->totalRcv - ((ptr->totalRcv >> 3) << 3) == 0)
						{

							ifMessageOut = true;
						}
						++(ptr->totalRcv);

						if (ptr->idxRcvBuf == ptr->nRcvBuf)
							ptr->idxRcvBuf = 0;

					}

					if (ifMessageOut)
					{
						ifMessageOut = false;
						std::cout << "totalRcvBufs2:" << ptr->totalRcv<< ", totalRcvBufToProc2:" << ptr->totalRcvBufToProc<< std::endl;
						//std::cout << "totalRcvBytes:" << totalRcv * ptr->sizeBuf
						//<< std::endl;
					}
					//ptr->recvEthFramesSize[idxRcvEthFrmPool] = n;
					//cout << line << endl;
                }
                ptr->packetCount++;
                }
                ixcap_free_pkt_buf(bufs[i]);
            }
         }



            else{
                           if(iftimeCounterFirst){
                               iftimeCounterFirst = false;
                               gettimeofday(&timingstart,NULL);

                           }
                           gettimeofday(&timingend,NULL);
                           //timing = timingend.tv_sec - timingstart.tv_sec;
                           timing =(timingend.tv_sec -timingstart.tv_sec)*1000+(timingend.tv_usec -timingstart.tv_usec)/1000;
                           //cout << "timing " << timing <<endl;
                           if(timing > 100){


                                first = true;
                               //system("echo 1 > /proc/sys/vm/drop_caches");


                           }
                           if( timing > 4*60*1000){
                              is_stop = true;
                              do_shutdown = 1;
                           }
                       }

		}
		else
		{

			const char *methods = "EthFrmRcvPool::init";
			Printglobal::doPrintErrorHints(methods,
					"warning : mac recv pool is filled.(If you see this warning ,it means"
					" BUFFERNUM should be modified and the program should "
					"be recompiled,or you may lose some frames)",
					__FILE__, __LINE__);
			usleep(1000);
		}

		//ptr->numPkts++;
		//ptr->numBytes += buffers[1]->len + 24; /* 8 Preamble + 4 CRC + 12 IFG
	}

}
void sigproc(int sig) {
	static int called = 0;
	printf("Leaving...\n");
	if(called) return; 
	else called = 1;

	do_shutdown = 1;
    is_stop = true;
    flags = true;
    //while_do1 = 1;

}
void initProductThread(const char* device1,const char* device2,COMMON *com){
	//int sock;
    //pthread_t my_thread[2];
        ixcapdev[0] = ixcap_init(device1,1,1);
        if(ixcapdev[0] == NULL)
        {
            printf("Init nic failure!\n");
            exit(-1);
        }
        ixcapdev[1] = ixcap_init(device2,1,1);
            if(ixcapdev[1] == NULL)
            {
                printf("Init nic failure!\n");
                exit(-1);
            }
  //  signal(SIGINT,  sigproc);
  //  signal(SIGTERM, sigproc);
    pthread_t my_thread[2];
/*int ret = pthread_create(&my_thread[0], NULL, productThread1);
  if(ret){
  std::cout << "pthread_create1 error in productThread.cpp." << endl;
  exit(1);
  }
  ret = pthread_create(&my_thread[1], NULL, productThread2);
  if(ret){
  std::cout << "pthread_create2 error in productThread.cpp." << endl;
  exit(1);
  }*/
    ThreadCreate::pthreadCreate(&my_thread[0], NULL, productThread1,(void*)com,__FILE__, __LINE__);
    ThreadCreate::pthreadCreate(&my_thread[1], NULL, productThread2,(void*)com,__FILE__, __LINE__);
   // flag = true;
    for(int i=0; i<2; i++){
        pthread_join(my_thread[i], NULL);

        sleep(1);

    }


}

