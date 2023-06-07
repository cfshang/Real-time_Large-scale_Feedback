function [RegConf]= FastultraSupervoxelSegmentation(filepath)
%%currently just for cytosol
%   env: environment variable (usually named env) of the pipeline script
%       which should contain:
%           env.height, env.width, env.depth, env.vol and env.volmask
%   opt: option variable (usually named opt) of the pipeline script
%        which should contain:
%           minrad: min radius of cell
%           maxrad: max radius of cell
%           thres:  threshold of a segmentation, 
%               the lower the thres, the more supervoxel will be found
%               default is [] for auto estimation
mkdir([filepath 'RegConf/'])
env.nHeight = 2048;
env.nWidth = 2048;
env.nDepth = 24;
env.vol = zeros(env.nHeight, env.nWidth, env.nDepth);
opt.rad = 5;
opt.maxrad = 6;
opt.minrad = 3;
opt.thres = 6/2048;
% opt.prcThres = 0.98;
opt.savepath = [filepath 'RegConf/'];

tic
disp 'running background segmentation...'
% caution: you may like to check the result of f-b segmentation
%[env.volmask, env.mask] = background_segmentation(env, opt);
multithreshcount = 2; %thresholding using the first percentile boundary level

dDepth = dir([filepath 'Avg/AVG_Stack_*.tif']);
whichDepth = nan(length(dDepth),1);
template = zeros(env.nHeight, env.nWidth, env.nDepth);
nPerDepth = zeros(length(dDepth),1);
for iDepth = 1:length(dDepth) % template including the mean raw images
    indind = strfind(dDepth(iDepth).name,'_');
    whichDepth(iDepth) = str2double(dDepth(iDepth).name(indind(2)+1:(end-4)))+1;
    tempImage = imread([filepath 'Avg/' dDepth(iDepth).name]);
    tempImage = im2double(tempImage);
    template(:,:,whichDepth(iDepth)) = template(:,:,whichDepth(iDepth)) + tempImage;
    nPerDepth(iDepth) = nPerDepth(iDepth) + 1;
end

for jDepth = 1:env.nDepth
    template(:,:,jDepth) = template(:,:,jDepth)./nPerDepth(jDepth);
    env.vol(:,:,jDepth) = template(:,:,jDepth);
    imwrite(im2uint16(template(:,:,jDepth)),[filepath 'Avg/template_' num2str(jDepth,'%02d') '.tif']);
end

% slice = mean(im2double(template, 3);
% level = multithresh(slice, 20);
slice = max(im2double(template), [], 3);
slice = rescalegd(slice, [0, 1/100]);  

pslice = imfilter(slice, fspecial('gaussian', opt.maxrad*2, opt.maxrad/2));
pslice = imdilate(pslice, strel('disk', opt.minrad));

try
    level = multithresh(pslice, 2); 
catch
    level = multithresh(pslice, 3);
end

level = level(1);
mask = imbinarize(pslice, level);
mask = imclose(mask, strel('disk', 10));
mask = imfill(mask, 'holes');
%mask = imfillholes(mask, [256, 256], 8);
% figure; imshow(pslice); figure; imshow(mask);

smvol = zeros(env.nHeight, env.nWidth, env.nDepth);
for kDepth = 1:env.nDepth
    slice = im2double(env.vol(:,:,kDepth));
    slice = normim(slice);
    slice = imdilate(slice, strel('disk', opt.minrad));
    smvol(:,:,kDepth) = slice;
end

normvol = normim(env.vol, [0 0]);  % normalize together

level = multithresh(smvol(:), multithreshcount);

volmask = false(size(env.vol));
for lDepth = 1:env.nDepth
    slice = smvol(:,:,lDepth);
    bw = imbinarize(slice, level(1));
%     bw = imfillholes(bw, [256, 256], 8);
    bw = bw & mask;
    volmask(:,:,lDepth) = bw;
end

% tiffwrite(im2uint8(volmask), [filepath '/result/volmask.tiff']);
% tiffwrite(im2uint8(cat(2, rescalegd(env.vol, [0 0]), env.volmask)), [filepath '/result/inspect_volmask.tiff']);
%volmask = tiffread('volmask.tiff');
%volmask = volmask > 100;
toc
%% supervoxel segmentation in 2 rounds
disp 'running supervoxel segmentation...';


radii = [opt.minrad opt.maxrad];
thres = opt.thres;
tic
%%obtaining scoremaps0 with pre-set threshold
% scoremaps0temp = nan(env.nHeight, env.nWidth, env.nDepth);
% volmasktemp = false(size(env.vol)); %layer background
smslicetemp = nan(size(env.vol));
center = cell(env.nDepth,1);
% rad = cell(env.nDepth,1);
nspv = zeros(env.nDepth,1);
% maskLR = nan(env.nDepth,2);
edge0 = [];
% poolsize = 12;%poolsize must be a factor of env.nDepth
% delete(gcp('nocreate'))
% parpool(poolsize);
% spmd
for ziDepth = 1:env.nDepth %(labindex-1)*(env.nDepth/poolsize)+1:labindex*(env.nDepth/poolsize)%
%     slice = smvol(:,:,ziDepth);
%     bw = slice > level(1);
%     bw = bw&mask;
%     volmasktemp(:,:,ziDepth) = bw;
    
    slice = normvol(:,:,ziDepth);
    gs = fspecial('gaussian', opt.maxrad, 1);
    smslicetemp(:,:,ziDepth) = imfilter(slice, gs);
    [points, ~, ~] = detect_by_ring_2d_n(smslicetemp(:,:,ziDepth), radii, thres, volmask(:,:,ziDepth));
    
%     maskYCollapse = sum(volmask(:,:,ziDepth),1);
%     backXL = find(maskYCollapse > 0, 1, 'first');
%     backXR = find(maskYCollapse > 0, 1, 'last');  
%     maskLR(ziDepth,:) = [backXL backXR];
    
    if sum(points(:)) == 0
        continue;
    end
   
    [yy, xx] = find(points);
    center{ziDepth} = [xx, yy];
    nspv(ziDepth) = size(center{ziDepth},1);
    
    iDepthDelta = ziDepth*ones(nspv(ziDepth) ,1);
    edgeDelta = [iDepthDelta-1 [xx-opt.rad, yy-opt.rad, xx+opt.rad, yy+ opt.rad]];
%     maskLRtemp = [1 1 2048 backXL; 1 backXR 2048 2048]; 
%     edgeBack = [ziDepth*ones(2,1) maskLRtemp];
%     edgeDelta = [edgeBack; edgeDelta];
    edge0 = [edge0; edgeDelta];
%     scoremaps0temp(:,:,ziDepth) = scoremap;
end
% end
toc


%% supervoxel rectangled and saved
    RegConf = nan(length(edge0), 8);
    RegConf(:,1) = 0:length(edge0)-1;
    RegConf(:,2) = 0; %group
    RegConf(:,3:7) = edge0;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
    RegConf(:,8) = 0; %weight


%% save segmentation result
dlmwrite([opt.savepath '/RegConf.txt'], RegConf, 'delimiter',' ');