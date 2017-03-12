%% expand original lat/lon matrix by five folds to match temperature size
% author: TengLi 20170311, litengbnu@foxmail.com, this is called function;
function out_geo = five_sample(in_geo)
[row, col] = size(in_geo);
out_geo = zeros(5*row, 5*col);
for ii = 1:row
    for jj = 1:col
        out_geo(5*ii-2, 5*jj-2) = in_geo(ii, jj);
    end
end
out_geo(out_geo == 0) = nan;
% http://cn.mathworks.com/matlabcentral/fileexchange/4551-inpaint-nans
out_geo = inpaint_nans(out_geo);
end
