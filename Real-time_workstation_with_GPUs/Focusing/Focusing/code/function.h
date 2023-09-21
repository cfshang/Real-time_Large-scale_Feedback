#ifndef FUNCTION_H
#define FUNCTION_H

#include <iostream>
#include <vector>
#include <string>
#include <stdio.h>
#include <stdlib.h>
#include <complex>
#include <cmath>
#include <math.h>
#include <float.h>
#include <algorithm>
#include <float.h>
#include <limits.h>
#include <tiffio.h>
#include <sys/time.h>
#include <omp.h>
#include <boost/property_tree/ptree.hpp>
#include <boost/property_tree/xml_parser.hpp>
#include <boost/foreach.hpp>
#include<sys/types.h>
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/core/utility.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include<sys/sysinfo.h>

#include<unistd.h>

#include <sched.h>


#define __USE_GNU

#include<sched.h>

#include<ctype.h>

#include <fstream>
#include <assert.h>
using namespace std;


#define THREAD_NUM 2

#define VALUE_POINTDENSITY 100
#define VALUE_SQUARESIZE 128
#define VALUE_MAXIMUMSHIFT 12
#define DEL_MIN INT_MIN
#define GPU_MAX 2
#define DEBUG 0
#define LOG 1
#define REG_NUM_MAX 100

#define MAX(a,b) {(a) < (b)? (b) : (a)}
#define MIN(a,b) {(a) < (b)? (a) : (b)}

#define BIND_CORE_THREAD_ROIQT 12
#define BIND_CORE_THREAD_PRODUCT1 13
#define BIND_CORE_THREAD_PRODUCT2 14

namespace pt = boost::property_tree;

/***** struct of the ROI position ****/
typedef struct tagROIPOSITION{
	unsigned int RegID;
	vector<unsigned int> x1;
	vector<unsigned int> y1;
	vector<unsigned int> x2;
	vector<unsigned int> y2;
	unsigned int ROInum;
}ROIPOSITION;
typedef struct tagROIVALUE{
	unsigned int RegID;
	unsigned int ROInum;
	vector< vector<float> > value;
	unsigned int ResNum;
}ROIVALUE;
/*** struct of  the maximum index ***/
typedef struct tagMAXINDEX{
	double max;
	int x;
	int y;
}MAXINDEX;
typedef struct tagPOSITION{
	unsigned int x_start;
	unsigned int y_start;
	unsigned int x_end;
	unsigned int y_end;
}POSITION;
typedef struct tagCOMMON{
	unsigned int width;
	unsigned int height;
	unsigned int length;
	vector<int> xx;
	vector<int> yy;
	vector<int> beginIndex;

	int* raw_xx_d;
	int* raw_yy_d;
	int* raw_beginIndex_d;
	unsigned int squareSize;
	unsigned int warpNum;
	unsigned int warpSize;
	unsigned int warpDataLen;
	long long warpDataLen_L;
	unsigned int pointDensity;
	unsigned int warpNumWidth;
	unsigned int warpNumHeight;

	size_t ws;

	unsigned int warpNum_512;
	unsigned int nFramePerRcvBuf;
	long int perbuffersize;
	//thrust::device_vector<float> meandata;
	float *raw_point_data;
	//thrust::device_vector<float> partial_sum_d(4096);
	float *partial_sum;
	// thrust::device_vector<float> sum_d(1);
	float *sum;

	float *raw_ifft_res;
	float *raw_fftshift_res;
	int *partial_index;

	float *maxdata;
	int *maxindex;

	int *raw_para_d;

	//thrust::device_vector<int> xshift_d;
	int *xshift_p;
	// thrust::device_vector<int> yshift_d;
	int *yshift_p;

	float *fdata_device;

	long int *raw_warpdatasize_d;


	int *dx;
	int *dy;

	int *mindex;
	// #pragma omp parallel for


}COMMON;
/***struct of xlat params,store the (dx,dy) offset***/
typedef struct tagPARAMSXLAT{
	int dx;
	int dy;

}PARAMSXLAT;

/***struct of warp params,store each warp (dx,dy) offset ***/
typedef struct tagPARAMSWARP{


}PARAMSWARP;

/*** struct of the image info ***/
typedef struct tagTIF{
	unsigned int width;
	unsigned int height;
	unsigned short channel;
	unsigned short bitspersample;
	unsigned int photometric;
	unsigned int samplesperpixel;
	unsigned short *sdata;
	vector<unsigned short> sdata_cpu;
	vector<float> fdata_cpu;
	vector<float> warpdata_cpu;
	unsigned int length;
	char *header; //TIF image's header
	unsigned int hdrSize; // header's size
	float *fdata;
	float *warpdata;


}TIF;

/*** struct of prereference info ***/
typedef struct tagPREREFERENCE{

	unsigned int pre_xlat_size;
	unsigned int pre_xlat_xsize;
	unsigned int pre_xlat_ysize;
	unsigned int pre_warp_size;
	unsigned int pre_warp_data_size;
	unsigned int pre_warp_data_xsize;
	unsigned int pre_warp_data_ysize;

}PREREFERENCE;
#define PICTUREWIDTH 2048
#define PICTUREHEIGHT 2048
#define block (1024*1024*1024*1)

typedef struct tagPARAMSCOPYTHREAD
{
	char *data;
	int size;
	int count_gpu;
	int pid;


}PARAMSCOPYTHREAD;
typedef struct tagPARAMSTHREAD{
	PREREFERENCE  **pre_refr;
	COMMON *com;
}PARAMSTHREAD;
/*** read and write the TIF image ***/
void prepare(COMMON *com,PREREFERENCE  **pre_refr);
int readTIF(const char *imagepath,TIF *tiff);
int writeTIF(const char *imgpathw,TIF *tiff,unsigned short *sdata);
void getwarpdatacpu(TIF &tiff);
/*** compute the average of an array ***/
double average(vector<double> &data);

/*** compute the mean of an array ***/
void arrayMeanRvn(vector<double> &data,double mean);

/*** prepare the reference***/
//void prepareReference(TIF &tiff,PREREFERENCE *pre_refr,COMMON &com);
void prepareReference(TIF &tiff,PREREFERENCE *pre_refr,COMMON &com,int count);
/** fftw and shift ***/


void fftshift2D(float *data,size_t width, size_t height);
void ifftshift2D(float *data,size_t width, size_t height);
/*** point multiplication ***/
void dotProduct(complex<double> *srcdata1, complex<double> *srcdata2,complex<double> *destdata,unsigned int size);
void swap(double *data1,double *data2);
/*** find not zero index of an array ***/
void findNotZeroIndex(PARAMSWARP &trans,vector<int> &index);

void findMaxIndex(float *data,int height,int width,MAXINDEX &res);
/*** compute conjugate complex ***/
//void arrayConj(complex<double> *data,complex<double> *res,int size); 

/*** get warp fft data ***/

//void frameRegistration(PREREFERENCE *pre_refr,TIF &tiff);
void frameRegisterXlat(PREREFERENCE *pre_refr,TIF *tiff,COMMON &com);

void framReformatXlat(TIF &tiff,PARAMSXLAT &xlat);
void frameRegisterWarp(PREREFERENCE *pre_refr,TIF *tiff,COMMON &com);

void frameRegistration(PREREFERENCE *pre_refr,TIF *tiff,int size);
void frameReformatWarp(TIF &tiff,PARAMSWARP &trans);

void frameReformatWarpdata(TIF *tiff,int *dx,int *dy,COMMON &com);
//void dotProduct(vector< complex<double> > &srcdata, vector< complex<double> > &destdata,unsigned int size);
int copyToDevice(int len,PARAMSTHREAD *para);
void multiBuffDeal(unsigned short **pdata, size_t size,int count_gpu);
void singleBuffDeal(size_t data_size,int count_gpu,PARAMSTHREAD *para);
int computeDevice(unsigned short *data_h,unsigned short *data, size_t size,int beginInd,int gid);
void finishMem(PARAMSTHREAD *para);
void initProductThread(const char* device1,const char* device2,COMMON *com);
void initConsumerThread(const char* device3,const char* device4,COMMON *com);
void startConsumerThread(const char* datastroe,COMMON *com);
int max_packet_len(const char *device) ;
void sigproc(int sig) ;
int max_packet_len_send(const char *device);
void sigproc_send(int sig);
void productPktNum(u_char *data,unsigned int idx);
void productPicNum(u_char *data,unsigned short idx);
void productRegNum(u_char *data,unsigned short idx);
void transformShort2Char(u_char *data,unsigned short *sdata,int size);

void transformChar2Short(u_char *src,unsigned short *dest,int length);
void transformChar2ShortandFloat(u_char *src,unsigned short *dest,float *fdest,int length);
void transformChar2Float(unsigned short *src,float *dest,int length);
unsigned int getPicIndex(u_char *packetIdBegin);
unsigned int getIndex(u_char *packetIdBegin);
int copydataModel(int number,int len,PARAMSTHREAD *para);
void singleBuffDealModel(int number,size_t data_size,int count_gpu,PARAMSTHREAD *para);

void readRegConf(string file, int regnum);
void computeROI(unsigned int RegID, unsigned short *pdata,COMMON *com);
void writeROI(string roifilename,unsigned int regNum);
unsigned short computeMean(unsigned short* data,int winsize,int width);
void removeMean(unsigned short *data,int width,int height, unsigned short mean,cv::Mat &img);
#endif
