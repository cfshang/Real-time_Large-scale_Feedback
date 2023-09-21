#ifndef CREATEFILEDIR_H
#define CREATEFILEDIR_H

#include <iostream>
#include <string>
#include <stdio.h>
#include <stdlib.h>
#include <dirent.h>
#include <list>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

using namespace std;
class CreateFileDir
{
public:
    CreateFileDir(string _srcfilepath);
    virtual ~CreateFileDir();

    void getFilePath();
    void createMultiLevel();
    string getPathDir(string filepath);

private:
    string srcfilepath;
    string filepath;

};

#endif // CREATEFILEDIR_H
