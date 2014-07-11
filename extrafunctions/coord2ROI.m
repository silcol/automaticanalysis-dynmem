%% coord2ROI
% This function creates an ROI nifti file, using as inputs 4 variables:
% 1) coord    -- coordinate in the template space (e.g. [10, 15, 17] mm in MNI)
% 2) radius   -- radius in the template space (e.g. 5 mm in MNI)
% 3) ROIname  -- name of the ROI (with '.nii' or '.img' extension)
% 4) template -- filename of the MNI or Talaraich template to use

function coord2ROI(coord, radius, ROIname, template)

if nargin < 1
    coord = [0 0 0]; % 46.0 64.0 37.0
end
if nargin < 2
    radius = 10; % in millimetres
end
if nargin < 3
    ROIname = 'myROI.nii';
end
if nargin < 4
    template = fullfile(spm('dir'), 'templates/T1.nii');
end

if ~iscell(coord)
    coord = {coord};
end

% Get the template...
V = spm_vol(template);

% Get the number of mm per voxel...
mmVox = vox2mm(V);

% Make radius in voxel space...
radius = [radius radius radius];
radius = radius ./ mmVox;

sM = 0;

for c = 1:length(coord)
    % Put coordinate vector in right orientation...
    coord{c} = coord{c}(:);
    
    % Transform coordinate system into voxels...
    coord{c} = V.mat \ [coord{c}; 1];
    coord{c} = coord{c}(1:3);
    
    % Create a meshgrid showing which voxels are here...
    [Y X Z] = meshgrid(1:V.dim(2), 1:V.dim(1), 1:V.dim(3));
    
    % Subtract from meshgrids our coordinates...
    X = X - coord{c}(1);
    Y = Y - coord{c}(2);
    Z = Z - coord{c}(3);
    
    % ...and divide by our radius
    X = X ./ radius(1);
    Y = Y ./ radius(2);
    Z = Z ./ radius(3);
    
    % Get absolute distance
    M = sqrt(X.^2 + Y.^2 + Z.^2);
    
    % ...and mask
    sM = sM + (M <= 1);    
end
sM = sM > 0;

% Write the mask
V.dt = [2 0];
V.fname = ROIname;

spm_write_vol(V, sM);