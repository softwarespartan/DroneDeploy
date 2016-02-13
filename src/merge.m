function I = merge(I1, K1, I2, K2)

    % create direction cosine matricies for camera
    O1 = dcm(K1(1),K1(2),K1(3));  O2 = dcm(K2(1),K2(2),K2(3));

    % create projective transforms to rectify images
    R1 = projective2d(inv(Rxy(O1)));  R2 = projective2d(inv(Rxy(O2)));

    % rectify each image
    I1 = imwarp(I1,R1); I2 = imwarp(I2,R2);

    % create grey scale images for feature extraction
    I1gray=rgb2gray(I1);  I2gray=rgb2gray(I2);
    
    % compute robust blobs
    blobs1 = detectSURFFeatures(I1gray, 'MetricThreshold', 2000);
    blobs2 = detectSURFFeatures(I2gray, 'MetricThreshold', 2000);
    
    % extract features from each gray scale image
    [features1, validBlobs1] = extractFeatures(I1gray, blobs1);
    [features2, validBlobs2] = extractFeatures(I2gray, blobs2);
    
    % match the features of each image to one another
    indexPairs = matchFeatures(features1, features2, 'Metric', 'SAD', 'MatchThreshold', 5);
    
    % turn the index into valid blobs
    matchedPoints1 = validBlobs1(indexPairs(:,1),:);
    matchedPoints2 = validBlobs2(indexPairs(:,2),:);
    
    [fMatrix, epipolarInliers, status]...
    = estimateFundamentalMatrix(matchedPoints1, matchedPoints2, ...
                                'Method'           , 'RANSAC' , ...
                                'NumTrials'        , 2000     , ...
                                'DistanceThreshold', 0.2      , ...
                                'Confidence'       , 99.99      ...
                               );
                           
    if status ~= 0 || isEpipoleInImage(fMatrix, size(I1)) || isEpipoleInImage(fMatrix', size(I2))
        error('Either not enough matching points were found ');
    end

    inlierPoints1 = matchedPoints1(epipolarInliers, :);
    inlierPoints2 = matchedPoints2(epipolarInliers, :);
    
    % compute the transformation between matched features
    tform = estimateGeometricTransform(inlierPoints1, inlierPoints2, 'projective');
    
    outputview = imref2d(size(I1));
    I1r = imwarp(I1,tform,'outputView',outputview);

    % calculate the images size (either image work since they are same size)
    imageSize = size(I1);
    
    % compute the combined image limits
    [xlim, ylim] = outputLimits(tform, [1 imageSize(2)], [1 imageSize(1)]);
    
    % compute xy-dims
    xMin = min([1; xlim(:)]);  xMax = max([imageSize(2); xlim(:)]);
    yMin = min([1; ylim(:)]);  yMax = max([imageSize(1); ylim(:)]);
    
    % Width and height of panorama.
    width  = round(xMax - xMin);  height = round(yMax - yMin);
    
    % create x and y limits`
    xLimits = [xMin xMax];  yLimits = [yMin yMax];
    
    % Initialize the "empty" panorama.
    I = zeros([height width 3], 'like', I1);
    
    % initialize 
    blender = vision.AlphaBlender('Operation', 'Binary mask', 'MaskSource', 'Input port');
    
    % init empty view
    panoramaView = imref2d([height width], xLimits, yLimits);
    
    % add image 1
    warpedImage = imwarp(I1r, projective2d(eye(3)), 'OutputView', panoramaView);
    I = step(blender, I, warpedImage, warpedImage(:,:,1));
    
    % add image 2
    warpedImage = imwarp(I2, projective2d(eye(3)), 'OutputView', panoramaView);
    I = step(blender, I, warpedImage, warpedImage(:,:,1));
    
    % create plots
    if(1)
       
        % show the rectified images
        imshowpair(I1,I2,'montage');
        
        % show matches points
        figure;
        showMatchedFeatures(I1, I2, matchedPoints1, matchedPoints2);
        legend('matched points in I1', 'matched points in I2');
        
        figure;
        showMatchedFeatures(I1, I2, inlierPoints1, inlierPoints2);
        legend('epipolar matches in I1', 'epipolar matches in I2');
        
        % show images transformed overlay with false coloring
        figure, imshowpair(I1r,I2)
        
        % show result
        figure;  imshow(I)
    end
    
    
end