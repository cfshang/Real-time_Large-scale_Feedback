/*
 * EthFrmRcvPool.cpp
 *
 *  Created on: 2015年9月2日
 *      Author: root
 */

#include "EthFrmRcvPool.h"

#include <stdlib.h>

#define BLOCKSIZE 512

EthFrmRcvPool::EthFrmRcvPool(size_t nRcvBuf , size_t nFramesInRcvBuf ,size_t sizeFrame,bool ifFilter,
		const string & logFileName ):	  fileLog(logFileName,ios::out	)
{

	this->ifFilter = ifFilter;
	this->nRcvBuf = nRcvBuf;
	this->nFramesInRcvBuf = nFramesInRcvBuf;
	this->sizeFrame = sizeFrame;
	sizeBuf = nFramesInRcvBuf*sizeFrame;
	this->picCount = 0;
	this->ifdealModel = true;
	this->ifdealData = false;
	this->ifNoDeal = true;
    //this->numModelPerETH = (_numModelPerETH / nFramesInRcvBuf + 1)*nFramesInRcvBuf;
    first = true;

	vRcvBuf.reserve(nRcvBuf);

	for (std::size_t i = 0; i < nRcvBuf; i++)
	{
		unsigned short *buffer;
		short *bufferIndex;
		float *fbuffer;
        /*if(NULL == (fbuffer = (float *)malloc(sizeof(float) * sizeBuf))){
            std::cout << "The float buffer malloc error in EthFrmRcvpool.cpp."<< i<<endl;
            exit(-1);
        }
        vRcvBufFloat.push_back(fbuffer);*/

        if(NULL == (buffer = (unsigned short *)malloc(sizeof(unsigned short) * sizeBuf))){
            std::cout << "The short buffer malloc error in EthFrmRcvpool.cpp."<< i<<endl;
            exit(-1);
        }

		vRcvBuf.push_back(buffer);


        if(NULL == (bufferIndex = (short *)malloc(sizeof(short) * sizeBuf))){
            std::cout << "The index buffer malloc error in EthFrmRcvpool.cpp."<< i<<endl;
            exit(-1);
        }
		vRcvBufIndex.push_back(bufferIndex);


		//else
		//std::cout << " ****************** fdata ok! " << endl;
		/*  if(NULL == (fbuffer = (float *)malloc(sizeof(float) * sizeBuf))){
		    std::cout << " the malloc fbuffer error in EthFrmRcvpool.cpp " << i << endl;
		    exit(-1);
		    };*/


		std::cout << "buffer "  << i << " alloc ok!" << endl;
	}
	std::cout << "vRcvBuf cudaHostAlloc end!" << endl;

}

EthFrmRcvPool::~EthFrmRcvPool()
{
	// TODO Auto-generated destructor stub
}

