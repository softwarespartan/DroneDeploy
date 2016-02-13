function I = merge(I1, K1, I2, K2)

    % create direction cosine matricies for camera
    O1 = dcm(K1(1),K1(2),K1(3));  O2 = dcm(K2(1),K2(2),K2(3));

    % create projective transforms to rectify images
    R1 = projective2d(inv(Rxy(O1)));  R2 = projective2d(inv(Rxy(O2)));

    % rectify each image
    [I1,view1] = imwarp(I1,R1); [I2,view2] = imwarp(I2,R2);

    % create grey scale images for feature extraction
    I1gray=rgb2gray(I1);  I2gray=rgb2gray(I2);
    
    % compute robust blobs
    blobs1 = detectSURFFeatures(I1gray, 'MetricThreshold', 2000);
    blobs2 = detectSURFFeatures(I2gray, 'MetricThreshold', 2000);
    
    % extract features from each gray scale image
    [features1, validBlobs1] = extractFeatures(I1gray, blobs1);
    [features2, validBlobs2] = extractFeatures(I2gray, blobs2);
    
    % match the features of each image to one another
    indexPairs = matchFeatures(features1, features2, 'Metric', 'SAD', 'MatchThreshold', 5,'Unique',1);
    
    % turn the index into valid blobs
    matchedPoints1 = validBlobs1(indexPairs(:,1),:);
    matchedPoints2 = validBlobs2(indexPairs(:,2),:);
    
    [fMatrix, epipolarInliers, status]...
        = estimateFundamentalMatrix(matchedPoints1, matchedPoints2, ...
                                'Method'           , 'RANSAC' , ...
                                'NumTrials'        , 2000     , ...
                                'DistanceThreshold', 0.1      , ...
                                'Confidence'       , 99.        ...
                               );
                           
    if status ~= 0 
        error('fundemental matrix calculation failed');
    end
    
    if (~isEpipoleInImage(fMatrix, size(I1)) || ~isEpipoleInImage(fMatrix', size(I2)))
        warning('epipole not in Image')
    end

    inlierPoints1 = matchedPoints1(epipolarInliers, :);
    inlierPoints2 = matchedPoints2(epipolarInliers, :);
    
    % compute the transformation between matched features
    tform = estimateGeometricTransform(inlierPoints1, inlierPoints2, 'projective');
    
    %outputview = imref2d(size(I1));
    [I1r,view1r] = imwarp(I1,tform);

    view2r = imref2d(size(I2));
    
    % calculate the images size (either image work since they are same size)
    xMin = min([view1r.XWorldLimits, view2r.XWorldLimits]);
    xMax = max([view1r.XWorldLimits, view2r.XWorldLimits]);
    
    yMin = min([view1r.YWorldLimits, view2r.YWorldLimits]);
    yMax = max([view1r.YWorldLimits, view2r.YWorldLimits]);
    
    % Width and height of panorama.
    width  = round(xMax - xMin);  height = round(yMax - yMin);
    
    % create x and y limits`
    xLimits = [xMin xMax];  yLimits = [yMin yMax];
    
    % Initialize the "empty" mosaic.
    I = zeros([height width 3], 'like', I1);
    
    % initialize 
    blender = vision.AlphaBlender('Operation', 'Binary mask', 'MaskSource', 'Input port');
    
    % init empty view
    mosaicView = imref2d([height width], xLimits, yLimits);
    
    % add image 1 
    wI = imwarp(I1, tform, 'OutputView', mosaicView);
    I = step(blender, I, wI, wI(:,:,1));
    
    % add image 2
    wI = imwarp(I2, projective2d(eye(3)), 'OutputView', mosaicView);
    I = step(blender, I, wI, wI(:,:,1));
    
    % compute empty space
    ix = (I(:,:,1)==0) & (I(:,:,2)==0)& (I(:,:,3)==0);  
    
    % figure out empty rows and columns
    ix1 = ~all(ix); ix2 = ~all(ix,2);
    
    % trim the image
    I = I(ix2,ix1,:);
    
    % create plots (or not)
    if(1)
       
        % show the rectified images
        figure;imshowpair(I1,I2,'montage');
        
        % show matches points
        figure;
        showMatchedFeatures(I1, I2, matchedPoints1, matchedPoints2);
        legend('matched points in I1', 'matched points in I2');
        
        figure;
        showMatchedFeatures(I1, I2, inlierPoints1, inlierPoints2);
        legend('epipolar matches in I1', 'epipolar matches in I2');
        
        % show images transformed overlay with false coloring
        figure, imshowpair(I1r,view1r,I2,imref2d(size(I2)))
        
        % show result
        figure;  imshow(I)
    end
end