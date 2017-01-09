function varargout = AR(varargin)
% AR MATLAB code for AR.fig
%      AR, by itself, creates a new AR or raises the existing
%      singleton*.
%
%      H = AR returns the handle to a new AR or the handle to
%      the existing singleton*.
%
%      AR('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in AR.M with the given input arguments.
%
%      AR('Property','Value',...) creates a new AR or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before AR_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to AR_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help AR

% Last Modified by GUIDE v2.5 15-Dec-2016 16:50:57

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @AR_OpeningFcn, ...
                   'gui_OutputFcn',  @AR_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before AR is made visible.
function AR_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to AR (see VARARGIN)

% Choose default command line output for AR
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes AR wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = AR_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in btnRunAR.
function btnRunAR_Callback(hObject, eventdata, handles)
% hObject    handle to btnRunAR (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global runAR ;
runAR = true ;
i = 0 ;
axes(handles.containerWebcam);


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




     while runAR 
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

        %needSURFCounter

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
                length(oldValidLocations)
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
                %figure(1);
                %imshow(outputFrame);        
                
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
           % figure(1);
            %imshow(outputFrame);
    
             imshow(outputFrame);
        end 

        needSURFCounter = needSURFCounter -1 ;

    end  % while    


    delete(cam);
    
    

    
% --- Executes on button press in btnStopAR.
function btnStopAR_Callback(hObject, eventdata, handles)
% hObject    handle to btnStopAR (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
global runAR ;
runAR = false ;
