#include "function.h"
#include "SerialPort.h"
#include "XmlConfig.h"
#include "ThreadFlags.h"
#include "FileLog.h"
using namespace  std;

extern vector<float> feedback_variance;
extern vector<float> feedback_mean;
extern ThreadFlags *flags;
extern XmlConfig *xmlConf;

unsigned char short2char(unsigned short sdata,bool islow){
    unsigned char cdata = 0;
    unsigned short mask_low = 0x00FF;
    unsigned short mask_high = 0xFF00;

    unsigned short tmp = 0;
    if(islow){
        tmp = sdata & mask_low;
        cdata = (unsigned char)tmp;
    }
    else{
        tmp = sdata & mask_high;
        cdata = (unsigned char)(tmp >> 8);
    }
    return cdata;
}

void startSerialPortThread(string serialpath){


    SerialPort serial(serialpath);
    int speed = 115200;
    int databits = 8;
    char parity ='n';
    int stopbits = 1;

    serial.setTTYSpeed(speed);
    serial.setTTYParity(databits,parity,stopbits);

    int preNumber = 0;
    int feedbackNum = feedback_variance.size();

    //unsigned char sendbuf_low[] = {0x01,0x06,0x00,0x00,0x00,0x01,0x48,0x0A}; // 0 - 0v
    //unsigned char sendbuf_high[] = {0x01,0x06,0x00,0x00,0x08,0x00,0x8E,0x0A}; //2048 -5v
    unsigned char sendbuf_low[] = {0xC0,0x00,0x00}; // 0 - 0v
    unsigned char sendbuf_high[] = {0xC0,0x0F,0xFF}; //2048 -5v
    float threshold_variance = xmlConf->getVarianceThreshold();
    float threshold_mean = xmlConf->getMeanThreshold();
    unsigned int filterNumber = xmlConf->getFilterNumber();
    bool ifFeedback = xmlConf->getIfFeedback();
    //sprintf(sendbuf1,"%x%x%x%x%x%x%x%x",0x01,0x06,0x00,0x00,0x00,0x00,0x89,0xCA);

   FileLog fileLog(xmlConf->getFeedbackDataPath(),ios::out);
   char feedbacklog[300];
   FileLog signalFileLog(xmlConf->getFeedbackSignalPath(),ios::out);
   char vfeedbacklog[300];
   FileLog vsignalFileLog(xmlConf->vfeedbackSignalPath,ios::out);
   FileLog vfileLog(xmlConf->vfeedbackDataPath,ios::out);
   char vsignallog[20];
   char signallog[20];
   int signallog_low = 0;
   int signallog_high = 1;
   long int count = 0;
   //bool ifsend = true;
   struct timeval start, end;
   long timing;
   flags->syncserial = false;
   vector<float> vsd;
   vector<float> vex;
   int winsize = 10;

    while(flags->ifsendserial){

        feedbackNum = feedback_variance.size();
        //

        if(flags->syncserial){
           // cout <<feedback.size() << " size " <<feedback[feedbackNum-1]  << "  feedback threshold: " << threshold << endl;
            // && feedbackNum > preNumber
            flags->syncserial = false;
             //float feedbackdata;

            //gettimeofday(&end,NULL);
           // timing =(end.tv_sec -start.tv_sec)*1000000+(end.tv_usec -start.tv_usec);
            //cout << "mathod 2 compute feedback cost :  "<< timing  << " us"<< endl;
            float feedbackdata_variance = feedback_variance[feedbackNum-1];
            float feedbackdata_mean = feedback_mean[feedbackNum-1];
            if(ifFeedback){
                sprintf(feedbacklog,"%f ",feedbackdata_variance);
                fileLog.dataRecord(feedbacklog);
                sprintf(vfeedbacklog,"%f ",feedbackdata_mean);
                vfileLog.dataRecord(vfeedbacklog);
                
                if(feedbackNum >filterNumber){
                    if(feedbackdata_variance < threshold_variance){
                        int sendret = serial.sendnTTY(sendbuf_low,sizeof(sendbuf_low));
                        /*if(sendret<=0){
                            cout << " Feedback send error." <<endl;
                        }*/
                       // cout << "Send low level signal : 0V , cnt :" << count <<" value: " << feedback[feedbackNum-1]<< endl;
                       // sprintf(feedbacklog, "Send low level signal : 0V , cnt :%d,value:%f,size:%d.\n",count,feedback[feedbackNum-1],feedbackNum);
                       // fileLog.logEthernetFrame(feedbacklog,0);
                        sprintf(signallog,"%d ",signallog_low);
                        signalFileLog.dataRecord(feedbacklog);
                        //count ++;
                    }
                    else{
                        int sendret = serial.sendnTTY(sendbuf_high,sizeof(sendbuf_high));
                        /*if(sendret<=0){
                            cout << " Feedback send error." <<endl;
                        }*/
                        sprintf(signallog,"%d ",signallog_high);
                        signalFileLog.dataRecord(feedbacklog);
                       // cout << "Send high level signal : 5V , cnt :" << count <<" value: " << feedback[feedbackNum-1]<< endl;
                       // sprintf(feedbacklog, "Send low level signal : 5V , cnt :%d,value:%f size:%d.\n",count,feedback[feedbackNum-1],feedbackNum);
                       // fileLog.logEthernetFrame(feedbacklog,5);

                        //count ++;
                    }
                }


            }
            else{
                sprintf(feedbacklog,"%f ",feedbackdata_mean);
                fileLog.dataRecord(feedbacklog);

                if(feedbackNum >filterNumber){
                    if(feedbackdata_mean < threshold_mean){
                        int sendret = serial.sendnTTY(sendbuf_low,sizeof(sendbuf_low));
                        /*if(sendret<=0){
                            cout << " Feedback send error." <<endl;
                        }*/
                        sprintf(signallog,"%d ",signallog_low);
                        signalFileLog.dataRecord(feedbacklog);
                       // cout << "Send low level signal : 0V , cnt :" << count <<" value: " << feedback[feedbackNum-1]<< endl;
                       // sprintf(feedbacklog, "Send low level signal : 0V , cnt :%d,value:%f,size:%d.\n",count,feedback[feedbackNum-1],feedbackNum);
                       // fileLog.logEthernetFrame(feedbacklog,0);

                        //count ++;
                    }
                    else{
                        int sendret = serial.sendnTTY(sendbuf_high,sizeof(sendbuf_high));
                        /*if(sendret<=0){
                            cout << " Feedback send error." <<endl;
                        }*/
                        sprintf(signallog,"%d ",signallog_high);
                        signalFileLog.dataRecord(feedbacklog);
                       // cout << "Send high level signal : 5V , cnt :" << count <<" value: " << feedback[feedbackNum-1]<< endl;
                       // sprintf(feedbacklog, "Send low level signal : 5V , cnt :%d,value:%f size:%d.\n",count,feedback[feedbackNum-1],feedbackNum);
                       // fileLog.logEthernetFrame(feedbacklog,5);
                        //sprintf(feedbacklog,"%f ",feedbackdata);
                        //fileLog.dataRecord(feedbacklog);
                        //count ++;
                    }
                }


            }

            preNumber = feedbackNum;
            //flags->syncserial = false;
            //gettimeofday(&end,NULL);
            //timing =(end.tv_sec -start.tv_sec)*1000+(end.tv_usec -start.tv_usec)/1000;
            //cout << "send feedback cost :  "<< timing  << " us"<< endl;
        }

    }

    serial.cleanTTY();
}
