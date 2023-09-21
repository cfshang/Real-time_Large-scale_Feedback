#include "CreateFileDir.h"

CreateFileDir::CreateFileDir(string _srcfilepath)
{
    srcfilepath = _srcfilepath;

    getFilePath();
}
void CreateFileDir::getFilePath(){
    filepath = srcfilepath;
    int pos = filepath.find_last_of('/');
    string prefilename = filepath.substr(pos,filepath.length()-pos);
    filepath.erase(pos);

}
void CreateFileDir::createMultiLevel(){
    string dir = filepath;
    if(access(dir.c_str(),00) == 0){
            return;
        }
        list<string> dirList;
        dirList.push_front(dir);
        string curDir = getPathDir(dir);
        while(curDir != dir){
            if(access(curDir.c_str(),00) == 0){
                break;
            }
            dirList.push_front(curDir);
            dir = curDir;
            curDir = getPathDir(dir);
        }
        for(auto it : dirList){
            mkdir(it.c_str(),S_IRWXU | S_IRWXG | S_IRWXO);
        }
}
string CreateFileDir::getPathDir(string path){
    string dirPath = path;
    size_t p = path.find_last_of('/');
    if(p != -1){
        dirPath.erase(p);
    }
    return dirPath;
}
CreateFileDir::~CreateFileDir(){

}
