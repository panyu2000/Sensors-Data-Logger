clc;
close all;
clear variables; %clear classes;
rand('state',0); % rand('state',sum(100*clock));
dbstop if error;

addpath('devkit_KITTI_GPS');


%% 1) load RoNIN IO data

% choose dataset path
datasetPath = 'G:\Smartphone_Dataset\4_WiFi_SfM\pyojin_Asus_Tango_SFU_Multiple_Buildings_withVIO';
datasetList = dir(datasetPath);
datasetList(1:2) = [];


% load RoNIN IO data
numDatasetList = 55;
datasetRoninIO = cell(1,numDatasetList);
for k = 1:numDatasetList
    
    % extract RoNIN data
    datasetDirectory = [datasetPath '\' datasetList(k).name];
    roninInterval = 200;          % 1 Hz
    roninYawRotation = 0;       % degree
    RoninIO = extractRoninCentricData(datasetDirectory, roninInterval, roninYawRotation, 100.0);
    
    
    % save RoNIN IO
    datasetRoninIO{k} = RoninIO;
    k
end


% unify Google FLP inertial frame in meter
datasetRoninIO = unifyRoninIOGoogleFLPMeterFrame(datasetRoninIO);


% Google FLP visualization
for k = 1:numDatasetList
    
    % current RoNIN IO data
    RoninIO = datasetRoninIO{k};
    RoninIOLocation = [RoninIO.FLPLocationMeter];
    
    
    % plot RoNIN IO location
    distinguishableColors = distinguishable_colors(numDatasetList);
    figure(10); hold on; grid on; axis equal; axis tight;
    plot(RoninIOLocation(1,:),RoninIOLocation(2,:),'*-','color',distinguishableColors(k,:),'LineWidth',1.5); grid on; axis equal;
    xlabel('X [m]','FontName','Times New Roman','FontSize',15);
    ylabel('Y [m]','FontName','Times New Roman','FontSize',15);
    set(gcf,'Units','pixels','Position',[150 60 1700 900]);  % modify figure
end


%% 2) optimize each RoNIN IO against Google FLP

%
for k = 1:numDatasetList
    
    % current RoNIN IO data
    RoninIO = datasetRoninIO{k};
    
    
    % nonlinear optimization with RoNIN drift correction model
    [RoninIO] = optimizeEachRoninIO(RoninIO);
    datasetRoninIO{k} = RoninIO;
end


% optimized RoNIN IO visualization
for k = 1:numDatasetList
    
    % current RoNIN IO data
    RoninIO = datasetRoninIO{k};
    RoninIOLocation = [RoninIO.location];
    
    
    % plot RoNIN IO location
    distinguishableColors = distinguishable_colors(numDatasetList);
    figure(10); hold on; grid on; axis equal; axis tight;
    plot(RoninIOLocation(1,:),RoninIOLocation(2,:),'-','color',distinguishableColors(k,:),'LineWidth',1.5); grid on; axis equal;
    xlabel('X [m]','FontName','Times New Roman','FontSize',15);
    ylabel('Y [m]','FontName','Times New Roman','FontSize',15);
    set(gcf,'Units','pixels','Position',[150 60 1700 900]);  % modify figure
end


%% temporary



k = 18;
RoninIO = datasetRoninIO{k};


%% (1) measurements (constants)

% RoNIN IO constraints (relative movement)
RoninPolarIO = convertRoninPolarCoordinate(RoninIO);
numRoninIO = size(RoninPolarIO,2);


% Google FLP constraints (global location)
RoninGoogleFLPIndex = [];
for k = 1:numRoninIO
    if (~isempty(RoninIO(k).FLPLocationMeter))
        RoninGoogleFLPIndex = [RoninGoogleFLPIndex, k];
    end
end
RoninGoogleFLPLocation = [RoninIO.FLPLocationMeter];


% check Google FLP data index
if (isempty(RoninGoogleFLPIndex))
    RoninIO = [];
    return;
end


% sensor measurements from RoNIN IO, Google FLP
sensorMeasurements.RoninPolarIODistance = [RoninPolarIO.distance];
sensorMeasurements.RoninPolarIOAngle = [RoninPolarIO.angle];
sensorMeasurements.RoninGoogleFLPIndex = RoninGoogleFLPIndex;
sensorMeasurements.RoninGoogleFLPLocation = RoninGoogleFLPLocation;
sensorMeasurements.RoninGoogleFLPAccuracy = [RoninIO.FLPAccuracyMeter];

sensorMeasurements.RoninStartLocation = landmark1;
sensorMeasurements.RoninEndLocation = landmark2;
sensorMeasurements.RoninAcceptableRadius = 2.0;


%% (2) model parameters (variables) for RoNIN IO drift correction model

% initialize RoNIN IO drift correction model parameters
modelParameters.startLocation = RoninGoogleFLPLocation(:,1).';
modelParameters.rotation = 0;
modelParameters.scale = ones(1,numRoninIO);
modelParameters.bias = zeros(1,numRoninIO);
X_initial = [modelParameters.startLocation, modelParameters.rotation, modelParameters.scale, modelParameters.bias];


%% (3) nonlinear optimization

% run nonlinear optimization using lsqnonlin in Matlab (Levenberg-Marquardt)
options = optimoptions(@lsqnonlin,'Algorithm','levenberg-marquardt','Display','iter-detailed','MaxIterations',400);
[vec,resnorm,residuals,exitflag] = lsqnonlin(@(x) EuclideanDistanceResidual_RoNIN_GoogleFLP_test(sensorMeasurements, x),X_initial,[],[],options);


% optimal model parameters for RoNIN IO drift correction model
RoninPolarIODistance = sensorMeasurements.RoninPolarIODistance;
RoninPolarIOAngle = sensorMeasurements.RoninPolarIOAngle;
X_optimized = vec;
[startLocation, rotation, scale, bias] = unpackDriftCorrectionRoninIOModelParameters(X_optimized);
RoninIOLocation = DriftCorrectedRoninIOAbsoluteAngleModel(startLocation, rotation, scale, bias, RoninPolarIODistance, RoninPolarIOAngle);


% % save drift-corrected RoNIN IO location
% for k = 1:numRoninIO
%     RoninIO(k).location = RoninIOLocation(:,k);
% end



