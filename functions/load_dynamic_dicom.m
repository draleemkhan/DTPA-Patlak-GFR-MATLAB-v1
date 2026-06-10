function [img, info] = load_dynamic_dicom(dicomFile)

info = dicominfo(dicomFile);
img = squeeze(dicomread(dicomFile));
img = double(img);

if ndims(img) ~= 3
    error('Selected DICOM is not a 3D dynamic image series.');
end

end