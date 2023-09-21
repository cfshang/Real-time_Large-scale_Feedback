/*
 * EthFrmRcvPool.h
 *
 *  Created on: 2015年9月2日
 *      Author: root
 */

#ifndef SRC_SELFMODULE_NET_ETHFRAMERCVPOOL_ETHFRMRCVPOOL_H_
#define SRC_SELFMODULE_NET_ETHFRAMERCVPOOL_ETHFRMRCVPOOL_H_

#include <stdlib.h>
#include <unistd.h>
#include <netinet/ip.h>
#include <netinet/if_ether.h>
#include <mutex>
#include "FileLog.h"
#include "Printglobal.h"

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

#define BUFFERNUM 1000000
#define MAXFRAMELENGTH  9000  //normal  should be  1518  , larger for in case
#define NUM_RCV_BUF  10

class EthFrmRcvPool
{
	public:
		EthFrmRcvPool(size_t nRcvBuf = 3, size_t nFramesInRcvBuf = 100000,
                size_t sizeFrame = 8192, bool ifFilter = false,
                const string & logFileName = "/home/ubuntu/recvlog/storeSrcImageLog.blackhole");
		virtual ~EthFrmRcvPool();


		std::size_t gSizeBuf() const
		{
			return sizeBuf;
		}

		unsigned short * curBufToProc()
		{
            /*while (1)
			{
				if (totalRcvBufToProc > 0)
				{

					return vRcvBuf[head];

				}
				else
					usleep(1000);
            }*/
            return vRcvBuf[head];

		}
		short * curBufIndexToProc()
		{
            /*while (1)
			{
				if (totalRcvBufToProc > 0)
				{

					return vRcvBufIndex[head];

				}
				else
					usleep(1000);
            }*/
            return vRcvBufIndex[head];


		}
		float * curBufFloatToProc()
		{
            /*while (1)
			{
				if (totalRcvBufToProc > 0)
				{

					return vRcvBufFloat[head];

				}
				else
					usleep(1000);
            }*/
            return vRcvBufFloat[head];


		}
		unsigned short * curBufToProc_deal()
		{
			while (1)
			{
				if (totalRcvBufToProc > 0)
				{

					return vRcvBuf[idxRcvBufToProc];

				}
				else
					usleep(1000);
			}

		}
		short * curBufIndexToProc_deal()
		{
			while (1)
			{
				if (totalRcvBufToProc > 0)
				{

					return vRcvBufIndex[idxRcvBufToProc];

				}
				else
					usleep(1000);
			}

		}
		float * curBufFloatToProc_deal()
		{
			while (1)
			{
				if (totalRcvBufToProc > 0)
				{

					return vRcvBufFloat[idxRcvBufToProc];

				}
				else
					usleep(1000);
			}

		}
		void finishCurBufProc()
		{

			poolMutex.lock();
			totalRcvBufToProc--;
			poolMutex.unlock();

			head++;
			if (head == nRcvBuf)
				head = 0;

		}
		void finishDealBufProc(){
			idxRcvBufToProc++;
			if (idxRcvBufToProc == nRcvBuf)
				idxRcvBufToProc = 0;
		}
		unsigned int getNumFrmsToPrcs()
		{
			return totalFrmsToProc;
		}

		const unsigned char * getCurFrame()
		{
			while (1)
			{
				if (totalFrmsToProc > 0)
				{
					return &recvEthFramesPool[idxFrmToProc][0];
				}
				else
					usleep(1000);
			}

		}

		void finishProcCurFrame()
		{

			poolMutex.lock();
			totalFrmsToProc--;
			poolMutex.unlock();

			if (idxFrmToProc == (BUFFERNUM - 1))
				idxFrmToProc = 0;
			else
				idxFrmToProc++;

		}
		int getSizeBuf(){
			int len = nFramesInRcvBuf * sizeFrame;
			return len;
		}
		void changeDealStaVar(){
			ifNoDeal = false;
		}
		void setIdxVar(){
			poolMutex.lock();


			idxRcvBufToProc = 0;
			head = 0;
			totalRcvBufToProc = 0;
			idxRcvBuf = 0;
			idxFrameInRcvBuf = 0;
			totalRcv = 0;
			frameIndex = 0;
			packetCount=0;
			poolMutex.unlock();
		}
		int getidxRcvBufToProc(){
			return idxRcvBufToProc;
		}
		int getBufHead(){
			return head;
		}
		int gettotalRcvBufToProc(){
            poolMutex.lock();
            int res = totalRcvBufToProc;

            poolMutex.unlock();
            return res;
		}
		int getidxRcvBuf(){
			return idxRcvBuf;
		}
		int getidxFrameInRcvBuf(){
			return idxFrameInRcvBuf;
		}

	public:
		std::mutex poolMutex;
		// unsigned char recvEthFramesPool[BUFFERNUM][MAXFRAMELENGTH];

		size_t nRcvBuf;
		size_t nFramesInRcvBuf;
		size_t sizeFrame;
		unsigned long long int totalRcv = 0;
		std::size_t idxRcvBuf = 0;
		std::size_t idxFrameInRcvBuf = 0;
		std::size_t frameIndex = 0;
		unsigned int packetCount = 0;
		std::size_t totalRcvBufToProc = 0;
		std::size_t idxRcvBufToProc = 0;
		std::size_t head = 0;
		std::size_t tail = 0;
		std::size_t sizeBuf = 0;
		short *recvEthFramesSize = new short[BUFFERNUM];
		unsigned int totalFrmsToProc = 0;
		unsigned int idxFrmToProc = 0;
		unsigned char (*recvEthFramesPool)[MAXFRAMELENGTH] =
			new unsigned char[BUFFERNUM][MAXFRAMELENGTH];
		//void * rcvBuf[NUM_RCV_BUF] ;
		std::vector<unsigned short *> vRcvBuf;
		std::vector<short *> vRcvBufIndex;
		std::vector<float *> vRcvBufFloat;

		bool ifFilter = false;
		FileLog fileLog;
		unsigned long long lostPacketNum = 0;
		unsigned long int picCount;
		bool ifdealModel;
		bool ifdealData;
		bool ifNoDeal;
		unsigned int numModelPerETH;
		struct timeval start, end;
        bool first;

};

#endif /* SRC_SELFMODULE_NET_ETHFRAMERCVPOOL_ETHFRMRCVPOOL_H_ */
