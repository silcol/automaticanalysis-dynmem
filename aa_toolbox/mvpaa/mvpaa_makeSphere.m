function [ Bx, By, Bz ] = mvpaa_makeSphere( aap )
%MAKE_SPHERE Makes a sphere
% The sphere is centred on one central voxel.
% The radius excludes the central voxel, so diameter is radius*2 + 1.

radius = aap.tasklist.currenttask.settings.ROIradius;

sphere=zeros(ceil(radius)*2 + 1, ceil(radius)*2 + 1,ceil(radius)*2 + 1);
[X, Y, Z] = meshgrid(1:(ceil(radius)*2 + 1), 1:(ceil(radius)*2 + 1), 1:(ceil(radius)*2 + 1));
X = X - (ceil(radius) + 1);
Y = Y - (ceil(radius) + 1);
Z = Z - (ceil(radius) + 1);
D = sqrt(X.^2 + Y.^2 + Z.^2);

% Get sphere by looking at radius
sphere(D < (radius + 0.001)) = 1;
ROIind = find(sphere==1);
[Bx, By, Bz] = ind2sub(size(sphere), ROIind);

% Base indices
Bx = Bx - aap.tasklist.currenttask.settings.ROIradius - 1;
By = By - aap.tasklist.currenttask.settings.ROIradius - 1;
Bz = Bz - aap.tasklist.currenttask.settings.ROIradius - 1;