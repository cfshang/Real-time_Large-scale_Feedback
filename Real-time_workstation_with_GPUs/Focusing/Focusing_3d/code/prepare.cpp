#include "function.h"


using namespace std;


extern TIF tiff[GPU_MAX];
extern POSITION ptn;

extern long long int buffersize;


void prepare(COMMON *com,PREREFERENCE  **pre_refr){
	//int k;
	//  COMMON com[GPU_MAX];
#pragma omp parallel for 
	for(int g=0; g<GPU_MAX; g++){

		//	pre_refr[g] = (PREREFERENCE *)malloc(sizeof(PREREFERENCE) * regNumber);
        /*int res = readTIF(referImage.c_str(),&pretiff[g]);
		if(!res){
			cout << "The preImage read error!"<< endl;

        }*/
		unsigned int width = ptn.x_end - ptn.x_start + 1;
		unsigned int height = ptn.y_end - ptn.y_start + 1;
		unsigned int length = width * height;
		com[g].width = width;
		com[g].height = height;
		com[g].length = length;
        //com[g].pointDensity = pointDensity;
		com[g].squareSize = VALUE_SQUARESIZE;
		com[g].warpNumWidth = (width - com[g].squareSize -com[g].squareSize) / com[g].pointDensity + 1;
		com[g].warpNumHeight = (height - com[g].squareSize -com[g].squareSize) / com[g].pointDensity +1 ;
		com[g].warpNum = com[g].warpNumWidth * com[g].warpNumHeight;
		com[g].warpSize = com[g].squareSize*2;
		com[g].warpDataLen = com[g].warpSize * com[g].warpSize ;
		com[g].perbuffersize = length * com[g].nFramePerRcvBuf;


		tiff[g].length = length;
		tiff[g].width = width;
		tiff[g].height = height;
        tiff[g].channel = 1;
        tiff[g].bitspersample = 16;
        tiff[g].photometric = 1;
        tiff[g].samplesperpixel = 1;


    }
}
