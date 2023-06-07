#include "function.h"
#include <signal.h>
#include <mutex>
#include "ThreadFlags.h"
#include "FileLog.h"
#include "XmlConfig.h"

extern vector<ROIPOSITION> roiptn;
extern vector<ROIVALUE> roivalues;
extern vector<ROIVALUE> roivalues_normal;
extern vector<ROIGROUP> roigroups;
extern vector<ROICONF> roiconfigtxt;
extern vector<float> feedback_variance;
extern vector<float> feedback_mean;
extern ThreadFlags *flags;
extern XmlConfig *xmlConf;
//extern COMMON com[GPU_MAX];
static int roiGroupCnt = 0;


void computeROI(unsigned int RegID, unsigned short *pdata,COMMON *com,int num,int regNum){
    unsigned int normalNumber = xmlConf->getNormalNumber();
    float normalPercent = xmlConf->getNormalPercent();
    int pointIndex = normalNumber * normalPercent - 1;
    float ROIFixed = xmlConf->getROIFixed();
    int groupnum = xmlConf->getRoiGroupNumber();
//#pragma omp parallel for
	for(int r=0; r< roiptn[RegID].ROInum; r++){
		int x1 = roiptn[RegID].x1[r];
		int y1 = roiptn[RegID].y1[r];
		int x2 = roiptn[RegID].x2[r];
		int y2 = roiptn[RegID].y2[r];
		float sum = 0.0;
		int sumcnt = (x2-x1+1)*(y2-y1+1);
		for(int y = y1; y <= y2; y++){
			for(int x = x1; x <= x2; x++){
				int srcptn = y * com[0].width + x;
				sum += (float)pdata[srcptn];
			}
		}
		float valtmp = sum / sumcnt;
        valtmp -= ROIFixed;
		roivalues[RegID].value[r].push_back(valtmp); 
        int roiValueSize = roivalues[RegID].value[r].size();

        if(roiValueSize > normalNumber){
            float arraySort[normalNumber];
            int indexCnt = 0;
            for(int d=roiValueSize-normalNumber; d < roiValueSize-1; d++){
                arraySort[indexCnt] = roivalues[RegID].value[r][d];
                indexCnt++;
            }
            sort(arraySort,arraySort+normalNumber);
            float normal = (roivalues[RegID].value[r][roiValueSize-1] / arraySort[pointIndex]) - 1;

            roivalues_normal[RegID].value[r].push_back(normal);

            unsigned int roiID = roivalues_normal[RegID].roiID[r];
            unsigned int groupID = roiconfigtxt[roiID].groupID;
            unsigned int indexInGroupValue = roigroups[groupID].roiIdInValueMap[roiID];
          //roiMutex.lock();
            roigroups[groupID].value[indexInGroupValue].push_back(normal);
            roigroups[groupID].ResNums[indexInGroupValue]++;
        }


        //roigroups_display[groupID].value[indexInGroupValue].push_back(valtmp);
        //roigroups_display[groupID].ResNums[indexInGroupValue]++;
        //roiMutex.unlock();
      //  cout << valtmp << "  " ;
	}
    roivalues[RegID].ResNum ++;
    flags->syncserial = false;

        if(num%regNum == (regNum-1)){

            roiGroupCnt++;
            if(roiGroupCnt > normalNumber){

                for(int g = 0;g<groupnum;g++){
                    roigroups[g].resNumFlag++;
                    //roigroups_display[g].resNumFlag++;
                }

                feedback_mean.push_back(0);
                feedback_variance.push_back(0);
                //float validRoiNumber = 0;
                int feedbackIndex = feedback_mean.size()-1;
                float validRoiNumber = roivalues_normal[0].validRoiNumber;
                for(int i=0; i< regNum; i++){
                     for(int j=0; j < roivalues_normal[i].ROInum; j++){
                         int valueSize = roivalues_normal[i].value[j].size();
                         feedback_mean[feedbackIndex] += (roivalues_normal[i].value[j][valueSize-1] * roiptn[i].weight[j]);
                         //validRoiNumber += roiptn[i].weight[j];
                     }
                 }
                 //assert(validRoiNumber!=0);
                 feedback_mean[feedbackIndex] /= validRoiNumber;
                 for(int i=0; i< regNum; i++){
                     for(int j=0; j < roivalues_normal[i].ROInum; j++){
                         int valueSize = roivalues_normal[i].value[j].size();
                         float tmp = pow((roivalues_normal[i].value[j][valueSize-1] -feedback_mean[feedbackIndex]),2.0);
                         feedback_variance[feedbackIndex] += (tmp * roiptn[i].weight[j]);
                     }
                 }
                 feedback_variance[feedbackIndex] /= (validRoiNumber-1);
                 //feedback_variance[feedbackIndex] = sqrt(feedback_variance[feedbackIndex]);
                 feedback_variance[feedbackIndex] = feedback_variance[feedbackIndex];
                 flags->syncserial = true;


            }

        }
        //sprintf(feedbacklog, " -- regid:%d,num:%d,num/regNum=%d,num%regNum=%d.\n",RegID,num,num/(regNum-1),num%(regNum-1));
        //fileLog.logEthernetFrame(feedbacklog,12);




    //cout << endl << RegID << " " << roivalues[RegID].ResNum << endl;
}
void writeROI(string roifilename,unsigned int regNum){
//#pragma omp parallel for
    for(int i=0; i< regNum; i++){
		char roioutfile[300];
		sprintf(roioutfile,"%s_%d.txt",roifilename.c_str(),i);
		ofstream outfile;
		outfile.open(roioutfile);
		assert(outfile.is_open());

        for(int j=0; j < roivalues_normal[i].ROInum; j++){
            for(int r=0; r < roivalues_normal[i].value[j].size(); r++){
                outfile << roivalues_normal[i].value[j][r] << " ";
			}
			outfile << endl;
		}
		outfile.close();
	}

}
