function [RegConf, vmap, roidfdf] = FastWeightAssignment1(filepath,nClust)
tic
env.nHeight = 2048;
env.nWidth = 2048;
env.nDepth = 24;
%% RegConf generated after template imaging and before spontaneous imaging
fid = fopen([filepath 'RegConf/RegConf.txt']); %'E:/20210308_fish1/20210308_1043/RegConf.txt'
RegConf0 = textscan(fid,'%f %f %f %f %f %f %f %f' );
fclose(fid);
Ind    = RegConf0{1};
Group  = RegConf0{2};
Layer  = RegConf0{3};
xLeft  = RegConf0{4};
yTop    = RegConf0{5};
xRight = RegConf0{6};
yBottom  = RegConf0{7};
weight = RegConf0{8};
RegConf = table(Ind,Group,Layer,xLeft,yTop,xRight,yBottom,weight);
clear RegConf0 Ind Group Layer xLeft yTop xRight yBottom weight ans fid
nspv = zeros(env.nDepth,1);
for iDepth = 1:env.nDepth
    nspv(iDepth) = sum(RegConf.Layer==iDepth-1);
end

%% Read roi data generated during spontaneous imaging
cd ([filepath 'roi/']);
roiactt = cell(env.nDepth,1);
nt = nan(env.nDepth,1);
droi = dir('roi_*.txt');
if ~isempty(droi)
    for idroi = 1:length(droi)
        if length(droi(idroi).name)<10
            movefile(droi(idroi).name,[droi(idroi).name(1:4) num2str(str2double(droi(idroi).name(5:end-4)),'%02d') droi(idroi).name(end-3:end)]);
        end
    end
    droi = dir('roi_*.txt');
    if length(droi)~=env.nDepth
        error('missing roi file!')
    end
    for idroi = 1:length(droi)
        if droi(idroi).bytes >0
            fid = fopen([filepath 'roi/' droi(idroi).name]);
            roiactt{idroi}=[];
            while ~feof(fid)
                roiactttemp = fgetl(fid);
                roiactttemp = str2num(roiactttemp); %%str2double则得nan；str2num则行向量转换                
                roiactt{idroi} = [roiactt{idroi};roiactttemp];
%                 roiacttTemp(sum(nspv(1:idroi-1))+1:sum(nspv(1:idroi)),:) = roiactttemp; %;
            end
        end
        nt(idroi) = size(roiactt{idroi},2);
%        roiacttTemp = textread([filepath '\roi\' droi(idroi).name]);%%用getl
%        roiactt = [roiactt; roiacttTemp];
    end    
end
clear roiactttemp
nt = min(nt);
roiactt0 = [];
for idroi = 1:length(droi)
    roiactt0 = [roiactt0;roiactt{idroi}(:,1:nt)];
end

roidfdf = roiactt0;
roidfdf(roidfdf<=-0.05) = 0;
%% Read behavior data

%% Sampling rate matching up

%% clustering
delete(gcp('nocreate'))
pool = parpool;                      % Invokes workers
stream = RandStream('mlfg6331_64');  % Random number stream
options = statset('UseParallel',1,'UseSubstreams',1,'Streams',stream);
[idx,C, ~,D] = kmeans(roidfdf,nClust,'Distance','Correlation','Replicates',5,'Options',options);
RegConf.Group = idx-1;
%% threshold

%% mapback
vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
for ii = 1:size(idx,1)
    vmap(RegConf.xLeft(ii):RegConf.xRight(ii), RegConf.yTop(ii):RegConf.yBottom(ii), RegConf.Layer(ii)+1) = idx(ii);
end
figure(100);clf
subplot(2,2,1)
imagesc(vmap(:,:,2),[0 nClust])
% hold on
% plot([0 2047],[0 0],'k-',[0 2047],[2047 2047],'k-',[1 1],[0 2047],'k-',[2047 2047],[0 2047],'k-')
subplot(2,2,2)
imagesc(vmap(:,:,9),[0 nClust])
% hold on
% plot([0 2047],[0 0],'k-',[0 2047],[2047 2047],'k-',[1 1],[0 2047],'k-',[2047 2047],[0 2047],'k-')
subplot(2,2,3)
imagesc(vmap(:,:,16),[0 nClust])
% hold on
% plot([0 2047],[0 0],'k-',[0 2047],[2047 2047],'k-',[1 1],[0 2047],'k-',[2047 2047],[0 2047],'k-')
subplot(2,2,4)
imagesc(vmap(:,:,22),[0 nClust])
% hold on
% plot([0 2047],[0 0],'k-',[0 2047],[2047 2047],'k-',[1 1],[0 2047],'k-',[2047 2047],[0 2047],'k-')
% generating weights and updating RegConf
RegConf.weight = zeros(length(RegConf.Group),1);
weightD = roundn(1./D,-4);
for iClust = 1:nClust
    weightDtemp = weightD(:,iClust);
    weightDtemp(RegConf.Group ~= iClust-1) = 0;
    RegConf.weight = weightDtemp;%(RegConf.Group == iClust-1);
    RegConfGroup = RegConf(RegConf.Group == iClust-1,:);
    [~,RegConfGroupSortind] = sort(RegConfGroup.weight,'descend');
    RegConfGroup = RegConfGroup(RegConfGroupSortind,:);
    RegConf(RegConf.Group == iClust-1,:) = RegConfGroup;
    dlmwrite([filepath 'RegConf' num2str(iClust) '.txt'], table2array(RegConf), 'delimiter',' ');
    
    vmapi = zeros(env.nHeight, env.nWidth, env.nDepth);
    for ii = 1:length(RegConf.Group)
        vmapi(RegConf.xLeft(ii):RegConf.xRight(ii), RegConf.yTop(ii):RegConf.yBottom(ii), RegConf.Layer(ii)+1) = RegConf.weight(ii);
    end
    figure(iClust);clf
    subplot(2,2,1)
    imagesc(vmapi(:,:,2),[0 1])
    subplot(2,2,2)
    imagesc(vmapi(:,:,9),[0 1])
    subplot(2,2,3)
    imagesc(vmapi(:,:,16),[0 1])
    subplot(2,2,4)
    imagesc(vmapi(:,:,22),[0 1])
    
    figure(100+iClust);clf
    temp = RegConf.weight;
    subplot(2,1,1)
    plot(temp'*roidfdf/sum(RegConf.weight));
    legend('Simulated feedback')
    subplot(2,1,2)
    plot(C(iClust,:));
    legend('Cluster center')
    
    RegConf.weight = zeros(length(RegConf.Group),1);
end
    toc
end