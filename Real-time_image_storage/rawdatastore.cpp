#include "mainwindow.h"
#include <QApplication>
#include "qcustomplot.h"
#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/xml_parser.hpp>
#include <boost/foreach.hpp>
#include <string>
#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <signal.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include "EthFrmRcvPool.h"
#include "ThreadCreate.h"
#include "function.h"
#include "CreateFileDir.h"


using namespace std;
namespace pt = boost::property_tree;

std::string device1;
std::string device2;
unsigned long int nRcvBuf ;
unsigned int regNumber;
long long int buffersize;
unsigned short  **pdata;
std::string dataStore;
std::string srcdataStore;
std::string modeldataStore;
std::string roivalueStore;
bool flags = false;
bool first = true;
bool ifstoresrc;
bool ifstoreModel;
bool ifstoreROI;
EthFrmRcvPool * pEthRcvPool[2];
string recvlogpath1;
string recvlogpath2;
TIF pretiff[GPU_MAX];
TIF tiff[GPU_MAX];
POSITION ptn;

int argc;
char **argv;
int do_shutdown;
bool is_stop;
int pauseTime;
struct timeval start,stop;
float diff;
void *
consumeFramestoGPU(void *arg)
{


    /*cpu_set_t mask;
    int cpu_id = 0;
    CPU_ZERO(&mask);
    CPU_SET(cpu_id,&mask);
    if(sched_setaffinity(0,sizeof(mask),&mask) == -1){
        cout << "The consumerFramestoGPU thread could not set cpu affinity ." << endl;
    }*/
   /* cpu_set_t mask;
    CPU_ZERO(&mask);
    CPU_SET(11,&mask);
    if(pthread_setaffinity_np(pthread_self(),sizeof(mask),&mask) == -1){
        cout << "The productThread thread could not set cpu affinity ." << endl;
        exit(-1);
    }*/
	PARAMSTHREAD *para = (PARAMSTHREAD *)arg;
	int count = 0;
	int length = para->com[0].length;
	int exeNumGPU = para->com[0].nFramePerRcvBuf;
	char outputfile[300];
	//char *filename = "CASIA";
    long int cnt=0;
	unsigned short *pt[THREAD_NUM];
	short *reg[THREAD_NUM];
	//omp_set_num_threads(exeNumGPU);
	bool ifdealModel = true;
	bool ifdealPic = false;
    is_stop = false;

	while (!is_stop)
	{
		//std::cout << "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" <<endl;
		/*if(do_shutdown && !pEthRcvPool[0]->totalRcvBufToProc && !pEthRcvPool[1]->totalRcvBufToProc){
		  flag = false;
		  break;
		  }*/
        if(pEthRcvPool[0]->gettotalRcvBufToProc() && pEthRcvPool[1]->gettotalRcvBufToProc()){
            reg[0] = pEthRcvPool[0]->curBufIndexToProc();
            reg[1] = pEthRcvPool[1]->curBufIndexToProc();
            pt[0] = pEthRcvPool[0]->curBufToProc();
            pt[1] = pEthRcvPool[1]->curBufToProc();
            int sizebuf = pEthRcvPool[0]->getSizeBuf();
            //int modInOnePool = numModelPerETH;


            //struct timeval start, end;
            //long timing;
           // gettimeofday(&start,NULL);
            for(int i=0; i < exeNumGPU; i++){
                for(int k=0;k<THREAD_NUM;k++){
                    long int n = cnt + k + i*THREAD_NUM;

                    sprintf(outputfile,"%s_%lld_%d.tif",srcdataStore.c_str(),n,reg[k][i]);
                    int res = writeTIF(outputfile,&tiff[0],pt[k]+i*length);
                    if(!res){
                        cout << "The srcImage write error!"<< n <<endl;
                        return 0;
                    }
                }
            }

            //gettimeofday(&end,NULL);
            //timing =(end.tv_sec -start.tv_sec)*1000+(end.tv_usec -start.tv_usec)/1000;
            //cout << "write 5 images cost  "<< timing  << " ms"<< endl;
            cnt += (exeNumGPU*THREAD_NUM);

            for(int i=0;i<THREAD_NUM;i++){
                pEthRcvPool[i]->finishCurBufProc();
            }
        }

       /* if(!pEthRcvPool[0]->gettotalRcvBufToProc()  && (!pEthRcvPool[1]->gettotalRcvBufToProc())){
            is_stop = true;
            cout << "end!" << endl;
        }*/




		//std:cout << ".................................copy ok!" << endl;

	}
	finishMem(para);
	//for(int i=0;i < pEthRcvPool->nRcvBuf;i++)
	//cudaFreeHost(pEthRcvPool->vRcvBuf[i]);

}
void *
callProductFuc(void *arg){
    /*cpu_set_t mask;
    int cpu_id = 2;
    CPU_ZERO(&mask);
    CPU_SET(cpu_id,&mask);
    if(sched_setaffinity(0,sizeof(mask),&mask) == -1){
        cout << "The consumerFramestoGPU thread could not set cpu affinity ." << endl;
    }*/
	COMMON *com = (COMMON *)arg;
    //printf("thread callproductfun productor 1\n");
	initProductThread(device1.c_str(),device2.c_str(),com);
    //printf("thread callproductfun productor 2\n");
}

int main(int _argc, char *_argv[])
{
	argc = _argc;
	argv = _argv;

    //signal(SIGPIPE, SIG_IGN);

	pt::ptree tree;

    std::string filename("RecvConf_StoreSrcData.xml");
	std::string roifilename("RegConf.txt");
	// Parse the XML into the property tree.
	pt::read_xml(filename, tree);
	string referImage;




	ifstoresrc = tree.get<bool>("rcvBufCfg.ifStoreSrcData");
	srcdataStore = tree.get<std::string>("rcvBufCfg.srcdataStore");

    //referImage = tree.get<std::string>("rcvBufCfg.referImage");
	device1 = tree.get<std::string>("rcvBufCfg.deviceName1");
	device2 = tree.get<std::string>("rcvBufCfg.deviceName2");


	nRcvBuf = tree.get("rcvBufCfg.nRcvBufPerPool", 0);
	unsigned long int nFramePerRcvBuf = tree.get("rcvBufCfg.nFramePerRcvBuf",
			0);
    //unsigned long int sizePerFrame = tree.get("rcvBufCfg.sizePerFrame", 0);,
	bool ifFilter = false;

	ptn.x_start = tree.get("rcvBufCfg.indexStartX",0);
	ptn.y_start = tree.get("rcvBufCfg.indexStartY",0);
	ptn.x_end = tree.get("rcvBufCfg.indexEndX",0);
	ptn.y_end = tree.get("rcvBufCfg.indexEndY",0);
    //pointDensity = tree.get("rcvBufCfg.pointDensity",0);
	regNumber = tree.get("rcvBufCfg.regNumber",0);
    //modelNumber = tree.get("rcvBufCfg.modelNumber",0);
    pauseTime = tree.get("rcvBufCfg.pauseTime",0);

    //recvlogpath1 = tree.get<std::string>("rcvBufCfg.recvLog1");
    //recvlogpath2 = tree.get<std::string>("rcvBufCfg.recvLog2");
    time_t ttime;
    struct tm *p;
    char ctime[100];
    time(&ttime);
    p = localtime(&ttime);
    strftime(ctime,sizeof(ctime),"%Y%m%d_%H%M",localtime(&ttime));
    string  stime = ctime;
    srcdataStore += stime ;
    recvlogpath1 += srcdataStore + "/srclog/srclog1";
    recvlogpath2 += srcdataStore + "/srclog/srclog2";
    srcdataStore += "/srcimage/src";

    CreateFileDir srcimgfiledir(srcdataStore);
    srcimgfiledir.createMultiLevel();
    CreateFileDir recvlog1(recvlogpath1);
    recvlog1.createMultiLevel();
    CreateFileDir recvlog2(recvlogpath2);
    recvlog2.createMultiLevel();


	//roivalues.resize(regNumber);

	usleep(100000);
	COMMON _com[2];

	COMMON *com = _com;
	com[0].nFramePerRcvBuf = nFramePerRcvBuf;
	com[1].nFramePerRcvBuf = nFramePerRcvBuf;
	// com = (COMMON *)malloc(sizeof(COMMON)*GPU_MAX);
	PREREFERENCE  **pre_refr;
	pre_refr = (PREREFERENCE**)malloc(sizeof(PREREFERENCE*)*GPU_MAX);
	PREREFERENCE pre_refr1[REG_NUM_MAX];
	PREREFERENCE pre_refr2[REG_NUM_MAX];
	pre_refr[0] = pre_refr1;
	pre_refr[1] = pre_refr2;
    prepare(com,pre_refr);
	cout << com[0].width << " " <<com[1].height << endl;

	unsigned long int sizePerFrame = com[0].length;
	buffersize = sizePerFrame * nFramePerRcvBuf;
	//    cout << "buffersize " << buffersize/1024/1024 << endl;
	pthread_t tid1;

	pthread_t tid3;

    //numModelPerETH = modelNumber/2;
    pEthRcvPool[0] = new EthFrmRcvPool(nRcvBuf, nFramePerRcvBuf, sizePerFrame,ifFilter,recvlogpath1);
    pEthRcvPool[1] = new EthFrmRcvPool(nRcvBuf, nFramePerRcvBuf, sizePerFrame,ifFilter,recvlogpath2);


	PARAMSTHREAD parameters;
	parameters.com = com;
	parameters.pre_refr = pre_refr;

	PARAMSTHREAD *point_para = &parameters;
	//   cout << "fdatasize :" << point_para->com[0].fdata_d.size() << endl;
	//   cout << "com.fdata.size: " << com[0].fdata_d.size() << endl;
    do_shutdown = 0;
    int res1 = ThreadCreate::pthreadCreate(&tid1, NULL, consumeFramestoGPU,(void*)point_para,__FILE__, __LINE__);
	//
    int res3 = ThreadCreate::pthreadCreate(&tid3, NULL, callProductFuc,(void*)com,__FILE__, __LINE__);

  //  initProductThread(device1.c_str(),device2.c_str(),com);
    pthread_join(tid1, NULL);
    pthread_join(tid3, NULL);
    system("echo 1 > /proc/sys/vm/drop_caches");
    cout <<"The program for storing image has been finished! " << endl;

      return 0;
}
