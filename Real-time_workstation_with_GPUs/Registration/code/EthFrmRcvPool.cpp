/*
 * EthFrmRcvPool.cpp
 *
 *  Created on: 2015年9月2日
 *      Author: root
 */

#include "EthFrmRcvPool.h"

#include <stdlib.h>

#define BLOCKSIZE 512

EthFrmRcvPool::EthFrmRcvPool(size_t nRcvBuf , size_t nFramesInRcvBuf ,size_t sizeFrame,bool ifFilter ,unsigned int _numModelPerETH,
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
	this->numModelPerETH = (_numModelPerETH / nFramesInRcvBuf + 1)*nFramesInRcvBuf;
    this->first = true;
	vRcvBuf.reserve(nRcvBuf);

	for (std::size_t i = 0; i < nRcvBuf; i++)
	{
		unsigned short *buffer;
		short *bufferIndex;
		float *fbuffer;
		cudaError_t a;
        //cudaHostAllocWriteCombined|
        a = cudaHostAlloc((void**)&buffer,sizeBuf*sizeof(unsigned short),cudaHostAllocMapped|cudaHostAllocPortable);
		if(a != cudaSuccess){
			std::cout << "The cudaHostAlloc error in EthFrmRcvpool.cpp."<< i<<endl;
			exit(-1);
		}

		vRcvBuf.push_back(buffer);

        a = cudaHostAlloc((void**)&bufferIndex,nFramesInRcvBuf*sizeof(unsigned short),cudaHostAllocMapped|cudaHostAllocPortable);
		if(a != cudaSuccess){
			std::cout << "The cudaHostAlloc index error in EthFrmRcvpool.cpp."<< i<<endl;
			exit(-1);
		}

		vRcvBufIndex.push_back(bufferIndex);

        a = cudaHostAlloc((void**)&fbuffer,sizeBuf*sizeof(float),cudaHostAllocMapped|cudaHostAllocPortable);
		if(a != cudaSuccess){
			std::cout << "The cudaHostAlloc fdata error in EthFrmRcvpool.cpp."<< i<<endl;
			exit(-1);
		}
		//else
		//std::cout << " ****************** fdata ok! " << endl;
		/*  if(NULL == (fbuffer = (float *)malloc(sizeof(float) * sizeBuf))){
		    std::cout << " the malloc fbuffer error in EthFrmRcvpool.cpp " << i << endl;
		    exit(-1);
		    };*/
		vRcvBufFloat.push_back(fbuffer);

        //std::cout << "buffer "  << i << " alloc ok!" << endl;
	}
	std::cout << "vRcvBuf cudaHostAlloc end!" << endl;

}

EthFrmRcvPool::~EthFrmRcvPool()
{
	// TODO Auto-generated destructor stub
}

