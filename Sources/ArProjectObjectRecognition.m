clear ;
close all;


% Step 1: Read Images

% Referenzbild
boxImage = imread('../covers/pulpfiction.jpg');
boxImage = rgb2gray(boxImage);
%figure;
%imshow(boxImage);
%title('Cover of Pulp Fiction');

% Szene
%sceneImageRGB = imread('images/pulpmitalbert.jpg');
%sceneImage = rgb2gray(sceneImageRGB);
%figure;
%imshow(sceneImage);
%title('Image of a Cluttered Scene');

% Webcam initialisieren
cam = webcam('Microsoft LifeCam HD-3000');
set(cam, 'Resolution', '640x480');
sceneImageRGB     = snapshot(cam);
%sceneImageRGB = imread('images/pulpmitalbert.jpg');
sceneImage = rgb2gray(sceneImageRGB);

% Video initialisieren
video = vision.VideoFileReader('../trailer/pulpfiction.mp4', ...
                                'VideoOutputDataType', 'uint8');
                          
for k=1:80
   step(video);
end

% Ersatzbild
% Bild auf die Größe Transformieren
%imageAlex = imread('../images/pulpmitalex.jpg');
imageAlex = step(video);
repDims = size(imageAlex(:,:,1));  % Auflösung des Videos
refDims = size(boxImage);  % Auflösung des Referenzbildes
% Transformationsmatrix ermitteln
yScale = refDims(1) / repDims(1) ;
xScale = refDims(2) / repDims(2) ;
scaleTransform = affine2d([xScale 0 0; 0 yScale 0; 0 0 1]);
imageAlexScaled = imwarp(imageAlex, scaleTransform);
%figure
%imshow(imageAlexScaled);

% Point-Tracker initialisieren (global)
pointTracker = vision.PointTracker('MaxBidirectionalError', 2);

inlierScenePoints = 0 ;
runPtTracker = false ;
usePtTracker = true ;
needSURFCounter = 10 ; % Counter bis wann wieder Surf notwendig ist.




for camLoop = 1 : 200
  % --------------- CAM-BILD AUFNEHMEN -------------------    
    % Webcam Bild aufnehmen
   % sceneImageRGB     = snapshot(cam);
   % sceneImage = rgb2gray(sceneImageRGB);

  %  figure(2);
  %  imshow(sceneImage);
  %  figure(1);

  
  % ---------- TRANSFORM VIDEO
    imageAlex = step(video);
    scaleTransform = affine2d([xScale 0 0; 0 yScale 0; 0 0 1]);
    imageAlexScaled = imwarp(imageAlex, scaleTransform);
  
   %--- Analyse ob PT oder SURF
    runPtTracker = false ;
    if ( length(inlierScenePoints) ~= 1 ) && ( needSURFCounter ~= 0 )
        runPtTracker = true && usePtTracker ;
    else
        needSURFCounter = 3 ;
    end
    
    needSURFCounter
    
   %--------------- POINT-TRACKER ------------------------
    
    if ( runPtTracker == true )
       pointTracker = vision.PointTracker('MaxBidirectionalError', 2);        
       initialize(pointTracker, inlierScenePoints.Location, sceneImageRGB);
       
       prevCamFrame    = sceneImageRGB ; %Test
       sceneImageRGB     = snapshot(cam);       
       
       [trackedPoints, isValid] = step(pointTracker, sceneImageRGB);
       % Use only the locations that have been reliably tracked
        newValidLocations = trackedPoints(isValid,:);
        oldValidLocations = inlierScenePoints.Location(isValid,:);
        
        if (nnz(isValid) >= 2) % Mindestens 2 getrackte Punkte zwischen den Frames sind notwendig
            [trackingTransform, oldInlierLocations, newInlierLocations] = ...
            estimateGeometricTransform(oldValidLocations, newValidLocations, 'Similarity');
            % Den Code könnte man später rausziehen und mit SURF
            % "verbinden"
            
            %figure(2);
           % showMatchedFeatures(prevCamFrame, sceneImageRGB, ...
            %        oldInlierLocations, newInlierLocations, 'Montage');

            setPoints(pointTracker, newValidLocations);
            trackingTransform.T = tform.T * trackingTransform.T;
            
            outputView = imref2d(size(sceneImage));
            imageAlexTransformed = imwarp(imageAlexScaled, trackingTransform, 'OutputView', outputView);
    
            mask = imageAlexTransformed(:,:,1) | ...
            imageAlexTransformed(:,:,2) | ...
            imageAlexTransformed(:,:,3) > 0 ;
   
            outputFrame = step(alphaBlender, sceneImageRGB, imageAlexTransformed, mask);
            %runPtTracker
            figure(1);
            imshow(outputFrame);        
            
        else
            runPtTracker = false ;
            inlierScenePoints = 0 ;
        end
            
    end % if runPtTracker
    
    
   %---------------- SURF FEATURES ----------------------- 
   
    if ( runPtTracker == false )
        
         % Webcam Bild aufnehmen
        sceneImageRGB     = snapshot(cam);
        sceneImage = rgb2gray(sceneImageRGB);
   
        % Step 2: Detect Feature Points
        boxPoints   = detectSURFFeatures(boxImage);
        scenePoints = detectSURFFeatures(sceneImage);

        % Step 3: Extract Feature Descriptors
        [boxFeatures, boxPoints]     = extractFeatures(boxImage, boxPoints);
        [sceneFeatures, scenePoints] = extractFeatures(sceneImage, scenePoints);

        % Step 4: Find Putative Point Matches
        boxPairs = matchFeatures(boxFeatures, sceneFeatures);

        outputFrame = sceneImageRGB ; % Initiale Vorbelegung, falls nichts transformiert wird.
        % Es muss nur ein Transform berechnet werden, wenn es genug Pairs gibt
        % Das soll ein gewissen rauschen verhindern.
        if ( length(boxPairs) > 10 ) 
            % Display putatively matched features
            matchedBoxPoints = boxPoints(boxPairs(:, 1), :);
            matchedScenePoints = scenePoints(boxPairs(:, 2), :);


            % Step 5: Locate the Object in the Scene Using Putative Matches
            % Destroys outliers
            [tform, inlierBoxPoints, inlierScenePoints] = ...
                estimateGeometricTransform(matchedBoxPoints, matchedScenePoints, 'affine');


            % Step 6: Ausgabebild erstellen
            outputView = imref2d(size(sceneImage));
            imageAlexTransformed = imwarp(imageAlexScaled, tform, 'OutputView', outputView);
            alphaBlender = vision.AlphaBlender('Operation', 'Binary mask', 'MaskSource', 'Input port');

            mask = imageAlexTransformed(:,:,1) | ...
                   imageAlexTransformed(:,:,2) | ...
                   imageAlexTransformed(:,:,3) > 0 ;


            outputFrame = step(alphaBlender, sceneImageRGB, imageAlexTransformed, mask);
        end  % if ( length(BoxPairs) > 40 ) 
        %runPtTracker
        figure(1);
        imshow(outputFrame);
    end 

    needSURFCounter = needSURFCounter -1 ;
    
end  % for..    
    


delete(cam);
 