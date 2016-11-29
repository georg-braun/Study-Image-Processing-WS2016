clear ;
close all;


% Step 1: Read Images

% Referenzbild
boxImage = imread('covers/pulpfiction.jpg');
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

% Ersatzbild
% Bild auf die Größe Transformieren
imageAlex = imread('images/pulpmitalex.jpg');
repDims = size(imageAlex(:,:,1));  % Auflösung des Videos
refDims = size(boxImage);  % Auflösung des Referenzbildes
% Transformationsmatrix ermitteln
yScale = refDims(1) / repDims(1) ;
xScale = refDims(2) / repDims(2) ;
scaleTransform = affine2d([xScale 0 0; 0 yScale 0; 0 0 1]);
imageAlexScaled = imwarp(imageAlex, scaleTransform);
%figure
%imshow(imageAlexScaled);

for camLoop = 1 : 200
    
    %pause(0.1); % Nur langsam Bilder machen

    % Webcam Bild aufnehmen
    sceneImageRGB     = snapshot(cam);
    sceneImage = rgb2gray(sceneImageRGB);

    % Step 2: Detect Feature Points
    boxPoints   = detectSURFFeatures(boxImage);
    scenePoints = detectSURFFeatures(sceneImage);

    %figure(1);
    %imshow(boxImage);
    %title('100 Strongest Feature Points from Box Image');
    %hold on;
    %plot(selectStrongest(boxPoints, 100));

    % Visualize strongest Points from target Image
    %figure(2);
    %imshow(sceneImage);
    %title('300 Strongest Feature Points from Scene Image');
    %hold on;
    %plot(selectStrongest(scenePoints, 300));



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
        %figure(3);
        %showMatchedFeatures(boxImage, sceneImage, matchedBoxPoints, ...
        %    matchedScenePoints, 'montage');
        %title('Putatively Matched Points (Including Outliers)');


        % Step 5: Locate the Object in the Scene Using Putative Matches

        % Destroys outliers
        [tform, inlierBoxPoints, inlierScenePoints] = ...
            estimateGeometricTransform(matchedBoxPoints, matchedScenePoints, 'affine');

        % Display with outliers removed
        %figure(4);
        %showMatchedFeatures(boxImage, sceneImage, inlierBoxPoints, ...
        %    inlierScenePoints, 'montage');
        %title('Matched Points (Inliers Only)');



        % Step 6: Ausgabebild erstellen
        outputView = imref2d(size(sceneImage));
        imageAlexTransformed = imwarp(imageAlexScaled, tform, 'OutputView', outputView);
        alphaBlender = vision.AlphaBlender('Operation', 'Binary mask', 'MaskSource', 'Input port');

        mask = imageAlexTransformed(:,:,1) | ...
               imageAlexTransformed(:,:,2) | ...
               imageAlexTransformed(:,:,3) > 0 ;


        outputFrame = step(alphaBlender, sceneImageRGB, imageAlexTransformed, mask);
    end ; % if ( length(BoxPairs) > 40 ) 
    figure(5);
    imshow(outputFrame);

end ; % for..    
    
delete(cam);
 