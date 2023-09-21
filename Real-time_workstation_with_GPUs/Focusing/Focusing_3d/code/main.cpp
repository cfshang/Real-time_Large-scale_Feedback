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


using namespace cv;
using namespace std;
namespace pt = boost::property_tree;

std::string device1;
std::string device2;
unsigned long int nRcvBuf ;
bool flags = false;
bool first = true;
EthFrmRcvPool * pEthRcvPool[2];

TIF tiff[GPU_MAX];
POSITION ptn;

int argc;
char **argv;
int do_shutdown;
bool is_stop;
struct timeval start,stop;
float diff;
void *
realtimedisplay(void *arg)
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
    int width = para->com[0].width;
    int height = para->com[0].height;
    int nFramePerRcvBuf = para->com[0].nFramePerRcvBuf;
	char outputfile[300];
	//char *filename = "CASIA";
    long int cnt=0;
	unsigned short *pt[THREAD_NUM];
	short *reg[THREAD_NUM];
	//omp_set_num_threads(exeNumGPU);
	bool ifdealModel = true;
	bool ifdealPic = false;
    is_stop = false;

    double dmin,dmax;
    int winSize = 700;
    char windowname[winNum][50] ={ "realtime_display layer 0","realtime_display layer 10","realtime_display layer 22"};
    for(int i = 0;i<winNum;i++){
        namedWindow(windowname[i]);
        resizeWindow(windowname[i],winSize,winSize);
    }

    //IplImage* img = cvCreateImage(cvSize(width,height),IPL_DEPTH_16U,1);
    Mat image = Mat::zeros(width,height,CV_8U);
   //Mat org;
   /* IplImage* image = cvLoadImage("img_0.tif",CV_LOAD_IMAGE_ANYDEPTH|CV_LOAD_IMAGE_ANYCOLOR);
    cvMinMaxLoc(image,&dmin,&dmax,NULL,NULL,NULL);
    cvScale(image,image,65535/(dmax-dmin),65535*(-(dmin+1)/(dmax-dmin)));
    Mat save = cv::cvarrToMat(image);
    namedWindow(windowname);
    resizeWindow(windowname,1024,1024);
    Mat small = Mat::zeros(1024,1024,CV_8UC1);
    resize(save,small,small.size());
    imshow(windowname,small);
    cv::waitKey(0);*/
    //int nFramePerRcvBuf = pEthRcvPool[0]->get
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


            for(int i=0; i < winNum; i++){
             //for(int k=0;k<THREAD_NUM;k++){

                        //unsigned short* data = (unsigned short *)(img->imageData);
                        //memcpy(data,pt[1]+i*length,sizeof(unsigned short)*length);
                        removeMean(pt[1]+i*length,width,height,image);

                        cv::minMaxLoc(image,&dmin,&dmax);
                        //cvScale(img,img,65535/(dmax-dmin),65535*(-(dmin+1)/(dmax-dmin)));
                        //Mat org = cv::cvarrToMat(img);
                        Mat small = Mat::zeros(winSize,winSize,CV_8UC1);
                        resize(image,small,small.size());
                        //cout << img->width << " " << img->height << endl;
                        //namedWindow(windowname[i]);
                        //resizeWindow(windowname[i],1024,1024);
                        imshow(windowname[i],small);
                        cvWaitKey(1);
                        //cout << "ok" <<endl;

             //}
            }



           // cnt += (exeNumGPU*THREAD_NUM);

            for(int i=0;i<THREAD_NUM;i++){
                pEthRcvPool[i]->finishCurBufProc();
            }
            //count++;

        }


	}
	finishMem(para);


}
void removeMean(unsigned short *data,int width,int height,Mat &img){
    for(int i=0;i<height;i++){
        for(int j=0;j<width;j++){
            int index = i*width+j;
            if(data[index] < 256)
                img.at<uchar>(index) = static_cast<uchar>(data[index]);
            else
                img.at<uchar>(index) = 255;
        }
    }
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
	printf("thread callproductfun productor 1\n");
	initProductThread(device1.c_str(),device2.c_str(),com);
	printf("thread callproductfun productor 2\n");
}

int main(int _argc, char *_argv[])
{
	argc = _argc;
	argv = _argv;

    //signal(SIGPIPE, SIG_IGN);

	pt::ptree tree;

    std::string filename("RecvConf_Focusing.xml");
	// Parse the XML into the property tree.
	pt::read_xml(filename, tree);
    //string referImage;




    //referImage = tree.get<std::string>("rcvBufCfg.referImage");
	device1 = tree.get<std::string>("rcvBufCfg.deviceName1");
	device2 = tree.get<std::string>("rcvBufCfg.deviceName2");


	nRcvBuf = tree.get("rcvBufCfg.nRcvBufPerPool", 0);
	unsigned long int nFramePerRcvBuf = tree.get("rcvBufCfg.nFramePerRcvBuf",
			0);
	//unsigned long int sizePerFrame = tree.get("rcvBufCfg.sizePerFrame", 0);
	bool ifFilter = false;

	ptn.x_start = tree.get("rcvBufCfg.indexStartX",0);
	ptn.y_start = tree.get("rcvBufCfg.indexStartY",0);
	ptn.x_end = tree.get("rcvBufCfg.indexEndX",0);
	ptn.y_end = tree.get("rcvBufCfg.indexEndY",0);
    //pointDensity = tree.get("rcvBufCfg.pointDensity",0);
    //regNumber = tree.get("rcvBufCfg.regNumber",0);

	std::cout << "nRcvBuf: " << nRcvBuf << "." << std::endl;
	std::cout << "nFramePerRcvBuf: " << nFramePerRcvBuf << "." << std::endl;
	//std::cout << "sizePerFrame: " << sizePerFrame << "." << std::endl;
	std::cout << "ifFilter: " << ifFilter << "." << std::endl;




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
	//    cout << "buffersize " << buffersize/1024/1024 << endl;
	pthread_t tid1;

	pthread_t tid3;

    pEthRcvPool[0] = new EthFrmRcvPool(nRcvBuf, nFramePerRcvBuf, sizePerFrame,ifFilter);
    pEthRcvPool[1] = new EthFrmRcvPool(nRcvBuf, nFramePerRcvBuf, sizePerFrame,ifFilter);


	PARAMSTHREAD parameters;
	parameters.com = com;
	parameters.pre_refr = pre_refr;

	PARAMSTHREAD *point_para = &parameters;
	//   cout << "fdatasize :" << point_para->com[0].fdata_d.size() << endl;
	//   cout << "com.fdata.size: " << com[0].fdata_d.size() << endl;
    do_shutdown = 0;
    int res1 = ThreadCreate::pthreadCreate(&tid1, NULL, realtimedisplay,(void*)point_para,__FILE__, __LINE__);
	//
    int res3 = ThreadCreate::pthreadCreate(&tid3, NULL, callProductFuc,(void*)com,__FILE__, __LINE__);

  //  initProductThread(device1.c_str(),device2.c_str(),com);
    pthread_join(tid1, NULL);
    pthread_join(tid3, NULL);


      return 0;
}
