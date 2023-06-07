function [RegConf2,RegConf4,RegConf6,RegConf8, RegConf16]= FastultraSupervoxelSegmentationPlane(filepath, LimTop, LimBottom,pos)
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
dbstop if error
mkdir([filepath 'RegConf/'])
env.nHeight = 2048;
env.nWidth = 2048;
env.nDepth = 1;
env.vol = zeros(env.nHeight, env.nWidth);
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

% dDepth = dir([filepath 'Avg/AVG_Stack_*.tif']);
% whichDepth = nan(length(dDepth),1);
% template = zeros(env.nHeight, env.nWidth);
% nPerDepth = zeros(length(dDepth),1);
% for iDepth = 1:length(dDepth) % template including the mean raw images
%     indind = strfind(dDepth(iDepth).name,'_');
%     whichDepth(iDepth) = str2double(dDepth(iDepth).name(indind(2)+1:(end-4)))+1;
    tempImage = imread([filepath 'Avg/AVG_Stack_0.tif']);% imread([filepath 'Avg/' dDepth(iDepth).name]);
    tempImage = im2double(tempImage);
    template = tempImage;
%     template(:,:,whichDepth(iDepth)) = template(:,:,whichDepth(iDepth)) + tempImage;
%     nPerDepth(iDepth) = nPerDepth(iDepth) + 1;
%     nPerDepth = 1;
% end

% for jDepth = 1:env.nDepth
%     template(:,:,jDepth) = template(:,:,jDepth)./nPerDepth(jDepth);
%     env.vol(:,:,jDepth) = template(:,:,jDepth);
    env.vol = template;
    imwrite(im2uint16(template),[filepath 'Avg/template_0.tif']);
%     imwrite(im2uint16(template(:,:,jDepth)),[filepath 'Avg/template_' num2str(jDepth,'%02d') '.tif']);
% end

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
% for kDepth = 1:env.nDepth
%     slice = im2double(env.vol(:,:,kDepth));
    slice = im2double(env.vol);
    slice = normim(slice);
    slice = imdilate(slice, strel('disk', opt.minrad));
%     smvol(:,:,kDepth) = slice;
    smvol = slice;
% end

normvol = normim(env.vol, [0 0]);  % normalize together

level = multithresh(smvol(:), multithreshcount);

% volmask = false(size(env.vol));
% for lDepth = 1:env.nDepth
%     slice = smvol(:,:,lDepth);
    slice = smvol;
    bw = imbinarize(slice, level(1));
%     bw = imfillholes(bw, [256, 256], 8);
    bw = bw & mask;
    volmask = bw;
%     volmask(:,:,lDepth) = bw;
% end

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
% smslicetemp = nan(size(env.vol));
% center = cell(env.nDepth,1);
% rad = cell(env.nDepth,1);
% nspv = zeros(env.nDepth,1);
% maskLR = nan(env.nDepth,2);
% edge0 = [];
% poolsize = 12;%poolsize must be a factor of envn.nDepth
% delete(gcp('nocreate'))
% parpool(poolsize);
% spmd
% for ziDepth = 1:env.nDepth %(labindex-1)*(env.nDepth/poolsize)+1:labindex*(env.nDepth/poolsize)%
%     slice = smvol(:,:,ziDepth);
%     bw = slice > level(1);
%     bw = bw&mask;
%     volmasktemp(:,:,ziDepth) = bw;
    
%     slice = normvol(:,:,ziDepth);
    slice = normvol;
    gs = fspecial('gaussian', opt.maxrad, 1);
%     smslicetemp(:,:,ziDepth) = imfilter(slice, gs);
    smslicetemp = imfilter(slice, gs);
%     [points, ~, ~] = detect_by_ring_2d_n(smslicetemp(:,:,ziDepth), radii, thres, volmask(:,:,ziDepth));

    switch pos 
        case  'cytosol'        
            thres = 2/2048;%%%added 20230204  
            [points, ~, ~] = detect_by_ring_2d_cytosol(smslicetemp, radii, thres, volmask);
    
%     maskYCollapse = sum(volmask(:,:,ziDepth),1);
%     backXL = find(maskYCollapse > 0, 1, 'first');
%     backXR = find(maskYCollapse > 0, 1, 'last');  
%     maskLR(ziDepth,:) = [backXL backXR];
    
%     if sum(points(:)) == 0
%         continue;
%     end
   
            [yy, xx] = find(points);
%     center{ziDepth} = [xx, yy];
            center = [xx yy];
            nspv = size(center,1);
%     nspv(ziDepth) = size(center{ziDepth},1);
    
%     iDepthDelta = ziDepth*ones(nspv(ziDepth) ,1);
%     edgeDelta = [iDepthDelta-1 [xx-opt.rad, yy-opt.rad, xx+opt.rad, yy+ opt.rad]];
            edge0 = [0*ones(nspv,1) [xx-opt.rad, yy-opt.rad, xx+opt.rad, yy+ opt.rad]];
%     maskLRtemp = [1 1 2048 backXL; 1 backXR 2048 2048]; 
%     edgeBack = [ziDepth*ones(2,1) maskLRtemp];
%     edgeDelta = [edgeBack; edgeDelta];
%     edge0 = [edge0; edgeDelta];
%     scoremaps0temp(:,:,ziDepth) = scoremap;
% end
% end
    %%%added 20230204

            edge2 = edge0;
    
            thres = 450/2048;
            [points, ~, ~] = detect_by_ring_2d_cytosol(smslicetemp, radii, thres, volmask);
            [yy, xx] = find(points);
            center = [xx yy];
            nspv = size(center, 1);
            edge450 = [0*ones(nspv, 1) [xx-opt.rad, yy-opt.rad, xx+opt.rad,yy+opt.rad]];
            
            thres = 500/2048;
            [points, ~, ~] = detect_by_ring_2d_cytosol(smslicetemp, radii, thres, volmask);
            [yy, xx] = find(points);
            center = [xx yy];
            nspv = size(center, 1);
            edge500 = [0*ones(nspv, 1) [xx-opt.rad, yy-opt.rad, xx+opt.rad,yy+opt.rad]];
            
            thres = 530/2048;
            [points, ~, ~] = detect_by_ring_2d_cytosol(smslicetemp, radii, thres, volmask);
            [yy, xx] = find(points);
            center = [xx yy];
            nspv = size(center, 1);
            edge530 = [0*ones(nspv, 1) [xx-opt.rad, yy-opt.rad, xx+opt.rad,yy+opt.rad]];
            
            thres = 550/2048;
            [points, ~, ~] = detect_by_ring_2d_cytosol(smslicetemp, radii, thres, volmask);
            [yy, xx] = find(points);
            center = [xx yy];
            nspv = size(center, 1);
            edge550 = [0*ones(nspv, 1) [xx-opt.rad, yy-opt.rad, xx+opt.rad,yy+opt.rad]];
            
        case 'n'
            thres = 2/2048;%%%added 20230204  
            [points, ~, ~] = detect_by_ring_2d_n(smslicetemp, radii, thres, volmask);
    
%     maskYCollapse = sum(volmask(:,:,ziDepth),1);
%     backXL = find(maskYCollapse > 0, 1, 'first');
%     backXR = find(maskYCollapse > 0, 1, 'last');  
%     maskLR(ziDepth,:) = [backXL backXR];
    
%     if sum(points(:)) == 0
%         continue;
%     end
   
            [yy, xx] = find(points);
%     center{ziDepth} = [xx, yy];
            center = [xx yy];
            nspv = size(center,1);
%     nspv(ziDepth) = size(center{ziDepth},1);
    
%     iDepthDelta = ziDepth*ones(nspv(ziDepth) ,1);
%     edgeDelta = [iDepthDelta-1 [xx-opt.rad, yy-opt.rad, xx+opt.rad, yy+ opt.rad]];
            edge0 = [0*ones(nspv,1) [xx-opt.rad, yy-opt.rad, xx+opt.rad, yy+ opt.rad]];
%     maskLRtemp = [1 1 2048 backXL; 1 backXR 2048 2048]; 
%     edgeBack = [ziDepth*ones(2,1) maskLRtemp];
%     edgeDelta = [edgeBack; edgeDelta];
%     edge0 = [edge0; edgeDelta];
%     scoremaps0temp(:,:,ziDepth) = scoremap;
% end
% end
    %%%added 20230204

            edge2 = edge0;
    
            thres = 4/2048;
            [points, ~, ~] = detect_by_ring_2d_n(smslicetemp, radii, thres, volmask);
            [yy, xx] = find(points);
            center = [xx yy];
            nspv = size(center, 1);
            edge4 = [0*ones(nspv, 1) [xx-opt.rad, yy-opt.rad, xx+opt.rad,yy+opt.rad]];
            
            thres = 6/2048;
            [points, ~, ~] = detect_by_ring_2d_n(smslicetemp, radii, thres, volmask);
            [yy, xx] = find(points);
            center = [xx yy];
            nspv = size(center, 1);
            edge6 = [0*ones(nspv, 1) [xx-opt.rad, yy-opt.rad, xx+opt.rad,yy+opt.rad]];
            
            thres = 8/2048;
            [points, ~, ~] = detect_by_ring_2d_n(smslicetemp, radii, thres, volmask);
            [yy, xx] = find(points);
            center = [xx yy];
            nspv = size(center, 1);
            edge8 = [0*ones(nspv, 1) [xx-opt.rad, yy-opt.rad, xx+opt.rad,yy+opt.rad]];
            
            thres = 16/2048;
            [points, ~, ~] = detect_by_ring_2d_n(smslicetemp, radii, thres, volmask);
            [yy, xx] = find(points);
            center = [xx yy];
            nspv = size(center, 1);
            edge16 = [0*ones(nspv, 1) [xx-opt.rad, yy-opt.rad, xx+opt.rad,yy+opt.rad]];        
    end
    %%%added 20230204   
toc


% %% supervoxel rectangled and saved
%     RegConf = nan(length(edge0), 8);
%     RegConf(:,1) = 1:length(edge0);
%     RegConf(:,2) = 0; %group
%     RegConf(:,3:7) = edge0;
% %     Layer  = RegConf0{3};
% %     xLeft  = RegConf0{4};
% %     yTop    = RegConf0{5};
% %     yRight = RegConf0{6};
% %     yBottom  = RegConf0{7};
%     RegConf(:,8) = 0; %weight
%     
% 
%     RegConf = RegConf((RegConf(:,5) > LimTop) &(RegConf(:,7) < LimBottom),:); 
%     if size(RegConf,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf(:,4),1-2000/size(RegConf,1));
%         RegConf = RegConf((RegConf(:,4) >= LimLeft),:);
%     end
% %     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
%     RegConf(:,1) = 0:1:size(RegConf,1)-1;
%     RegConf(1:4,8) = 1;
%     
switch pos
    case 'cytosol'
        %% supervoxel rectangled and saved
        RegConf2 = nan(length(edge2), 8);
        RegConf2(:,1) = 1:length(edge2);
        RegConf2(:,2) = 0; %group
        RegConf2(:,3:7) = edge2;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     xRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf2(:,8) = 0; %weight    

        RegConf2 = RegConf2((RegConf2(:,5) > LimTop) &(RegConf2(:,7) < LimBottom),:); 
%     if size(RegConf2,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf2(:,4),1-2000/size(RegConf2,1));
%         RegConf2 = RegConf2((RegConf2(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf2(:,1) = 0:1:size(RegConf2,1)-1;
        RegConf2(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf2,1)
            vmap(RegConf2(ii,4):RegConf2(ii,6), RegConf2(ii,5):RegConf2(ii,7), RegConf2(ii,2)+1) = 1;
        end
        figure(2);clf
        imagesc(vmap, [0 1])
    
    %% supervoxel rectangled and saved
        RegConf500 = nan(length(edge500), 8);
        RegConf500(:,1) = 1:length(edge500);
        RegConf500(:,2) = 0; %group
        RegConf500(:,3:7) = edge500;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf500(:,8) = 0; %weight
    
        RegConf500 = RegConf500((RegConf500(:,5) > LimTop) &(RegConf500(:,7) < LimBottom),:); 
%     if size(RegConf4,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf4(:,4),1-2000/size(RegConf4,1));
%         RegConf4 = RegConf4((RegConf4(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf500(:,1) = 0:1:size(RegConf500,1)-1;
        RegConf500(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf500,1)
            vmap(RegConf500(ii,4):RegConf500(ii,6), RegConf500(ii,5):RegConf500(ii,7), RegConf500(ii,2)+1) = 1;
        end
        figure(500);clf
        imagesc(vmap, [0 1])
    
    %% supervoxel rectangled and saved
        RegConf450 = nan(length(edge450), 8);
        RegConf450(:,1) = 1:length(edge450);
        RegConf450(:,2) = 0; %group
        RegConf450(:,3:7) = edge450;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf450(:,8) = 0; %weight    

        RegConf450 = RegConf450((RegConf450(:,5) > LimTop) &(RegConf450(:,7) < LimBottom),:); 
%     if size(RegConf6,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf6(:,4),1-2000/size(RegConf6,1));
%         RegConf6 = RegConf6((RegConf6(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf450(:,1) = 0:1:size(RegConf450,1)-1;
        RegConf450(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf450,1)
            vmap(RegConf450(ii,4):RegConf450(ii,6), RegConf450(ii,5):RegConf450(ii,7), RegConf450(ii,2)+1) = 1;
        end
        figure(450);clf
        imagesc(vmap, [0 1])
    
    %% supervoxel rectangled and saved
        RegConf530 = nan(length(edge530), 8);
        RegConf530(:,1) = 1:length(edge530);
        RegConf530(:,2) = 0; %group
        RegConf530(:,3:7) = edge530;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf530(:,8) = 0; %weight    

        RegConf530 = RegConf530((RegConf530(:,5) > LimTop) &(RegConf530(:,7) < LimBottom),:); 
%     if size(RegConf8,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf8(:,4),1-2000/size(RegConf8,1));
%         RegConf8 = RegConf8((RegConf8(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf530(:,1) = 0:1:size(RegConf530,1)-1;
        RegConf530(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf530,1)
            vmap(RegConf530(ii,4):RegConf530(ii,6), RegConf530(ii,5):RegConf530(ii,7), RegConf530(ii,2)+1) = 1;
        end
        figure(530);clf
        imagesc(vmap, [0 1])
    
    %% supervoxel rectangled and saved
        RegConf550 = nan(length(edge550), 8);
        RegConf550(:,1) = 1:length(edge550);
        RegConf550(:,2) = 0; %group
        RegConf550(:,3:7) = edge550;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf550(:,8) = 0; %weight
    
        RegConf550 = RegConf550((RegConf550(:,5) > LimTop) &(RegConf550(:,7) < LimBottom),:); 
%     if size(RegConf8,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf10(:,4),1-2000/size(RegConf10,1));
%         RegConf10 = RegConf10((RegConf10(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf550(:,1) = 0:1:size(RegConf550,1)-1;
        RegConf550(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf550,1)
            vmap(RegConf550(ii,4):RegConf550(ii,6), RegConf550(ii,5):RegConf550(ii,7), RegConf550(ii,2)+1) = 1;
        end
        figure(550);clf
        imagesc(vmap, [0 1])
        
        %% save segmentation result
        % dlmwrite([opt.savepath '/RegConf.txt'], RegConf, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf2.txt'], RegConf2, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf450.txt'], RegConf450, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf500.txt'], RegConf500, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf530.txt'], RegConf530, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf550.txt'], RegConf550, 'delimiter',' ');
        RegConf4=RegConf450; RegConf6=RegConf500; RegConf8=RegConf530; RegConf16=RegConf550;
        
        case 'n'
            %% supervoxel rectangled and saved
        RegConf2 = nan(length(edge2), 8);
        RegConf2(:,1) = 1:length(edge2);
        RegConf2(:,2) = 0; %group
        RegConf2(:,3:7) = edge2;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     xRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf2(:,8) = 0; %weight    

        RegConf2 = RegConf2((RegConf2(:,5) > LimTop) &(RegConf2(:,7) < LimBottom),:); 
%     if size(RegConf2,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf2(:,4),1-2000/size(RegConf2,1));
%         RegConf2 = RegConf2((RegConf2(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf2(:,1) = 0:1:size(RegConf2,1)-1;
        RegConf2(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf2,1)
            vmap(RegConf2(ii,4):RegConf2(ii,6), RegConf2(ii,5):RegConf2(ii,7), RegConf2(ii,2)+1) = 1;
        end
        figure(2);clf
        imagesc(vmap, [0 1])
    
    %% supervoxel rectangled and saved
        RegConf4 = nan(length(edge4), 8);
        RegConf4(:,1) = 1:length(edge4);
        RegConf4(:,2) = 0; %group
        RegConf4(:,3:7) = edge4;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf4(:,8) = 0; %weight
    
        RegConf4 = RegConf4((RegConf4(:,5) > LimTop) &(RegConf4(:,7) < LimBottom),:); 
%     if size(RegConf4,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf4(:,4),1-2000/size(RegConf4,1));
%         RegConf4 = RegConf4((RegConf4(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf4(:,1) = 0:1:size(RegConf4,1)-1;
        RegConf4(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf4,1)
            vmap(RegConf4(ii,4):RegConf4(ii,6), RegConf4(ii,5):RegConf4(ii,7), RegConf4(ii,2)+1) = 1;
        end
        figure(4);clf
        imagesc(vmap, [0 1])
    
    %% supervoxel rectangled and saved
        RegConf6 = nan(length(edge6), 8);
        RegConf6(:,1) = 1:length(edge6);
        RegConf6(:,2) = 0; %group
        RegConf6(:,3:7) = edge6;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf6(:,8) = 0; %weight    

        RegConf6 = RegConf6((RegConf6(:,5) > LimTop) &(RegConf6(:,7) < LimBottom),:); 
%     if size(RegConf6,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf6(:,4),1-2000/size(RegConf6,1));
%         RegConf6 = RegConf6((RegConf6(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf6(:,1) = 0:1:size(RegConf6,1)-1;
        RegConf6(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf6,1)
            vmap(RegConf6(ii,4):RegConf6(ii,6), RegConf6(ii,5):RegConf6(ii,7), RegConf6(ii,2)+1) = 1;
        end
        figure(6);clf
        imagesc(vmap, [0 1])
    
    %% supervoxel rectangled and saved
        RegConf8 = nan(length(edge8), 8);
        RegConf8(:,1) = 1:length(edge8);
        RegConf8(:,2) = 0; %group
        RegConf8(:,3:7) = edge8;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf8(:,8) = 0; %weight    

        RegConf8 = RegConf8((RegConf8(:,5) > LimTop) &(RegConf8(:,7) < LimBottom),:); 
%     if size(RegConf8,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf8(:,4),1-2000/size(RegConf8,1));
%         RegConf8 = RegConf8((RegConf8(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf8(:,1) = 0:1:size(RegConf8,1)-1;
        RegConf8(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf8,1)
            vmap(RegConf8(ii,4):RegConf8(ii,6), RegConf8(ii,5):RegConf8(ii,7), RegConf8(ii,2)+1) = 1;
        end
        figure(8);clf
        imagesc(vmap, [0 1])
    
    %% supervoxel rectangled and saved
        RegConf16 = nan(length(edge16), 8);
        RegConf16(:,1) = 1:length(edge16);
        RegConf16(:,2) = 0; %group
        RegConf16(:,3:7) = edge16;
%     Layer  = RegConf0{3};
%     xLeft  = RegConf0{4};
%     yTop    = RegConf0{5};
%     yRight = RegConf0{6};
%     yBottom  = RegConf0{7};
        RegConf16(:,8) = 0; %weight
    
        RegConf16 = RegConf16((RegConf16(:,5) > LimTop) &(RegConf16(:,7) < LimBottom),:); 
%     if size(RegConf8,1) > 2000 %maximal numer of roi's. For 50 Hz, this is probably 5000      
%         LimLeft = quantile(RegConf10(:,4),1-2000/size(RegConf10,1));
%         RegConf10 = RegConf10((RegConf10(:,4) >= LimLeft),:);
%     end
%     RegConf(:,1) = RegConf(:,1) - RegConf(1,1);
        RegConf16(:,1) = 0:1:size(RegConf16,1)-1;
        RegConf16(1:4,8) = 1;
    
        vmap = zeros(env.nHeight, env.nWidth, env.nDepth);
        for ii = 1:size(RegConf16,1)
            vmap(RegConf16(ii,4):RegConf16(ii,6), RegConf16(ii,5):RegConf16(ii,7), RegConf16(ii,2)+1) = 1;
        end
        figure(16);clf
        imagesc(vmap, [0 1])
        
        %% save segmentation result
        % dlmwrite([opt.savepath '/RegConf.txt'], RegConf, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf2.txt'], RegConf2, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf4.txt'], RegConf4, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf6.txt'], RegConf6, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf8.txt'], RegConf8, 'delimiter',' ');
        dlmwrite([opt.savepath '/RegConf16.txt'], RegConf16, 'delimiter',' ');        
        
end