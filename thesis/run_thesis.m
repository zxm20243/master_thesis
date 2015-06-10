function run_thesis(image_list)

    % -------------------------------------------------------------------------
    %  Parse File & Generate Stratify K-fold split
    % -------------------------------------------------------------------------

    setup_3rdparty(fullfile('~/Software'))
    [prefix, label, path] = parse_list(image_list);
    folds = cross_validation(label, 5);

    % -------------------------------------------------------------------------
    %  Feature Extraction
    % -------------------------------------------------------------------------

    %sift = extract_sift(path);
    %lbp = extract_lbp(path, 3, 1 / 2);
    %hog = extract_descriptor(path, 'hog');
    %phow = extract_descriptor(path, 'phow');
    %color_lbp = extract_descriptor(path, 'color_lbp');

    %save([prefix, '.mat'], 'sift', 'lbp');


    % -------------------------------------------------------------------------
    %  Directly Training
    % -------------------------------------------------------------------------

    %ds = reshape(cell2mat(ds), [], length(ds));
    %train(double(label), sparse(double(ds)), '-v 5 -q', 'col');

    % -------------------------------------------------------------------------
    %  Bag-of-Word with Hierarchical K-means Codebook, Encoding with LLC
    % -------------------------------------------------------------------------

    %cv = 1;
    %train_idx = folds(cv).train;
    %test_idx = folds(cv).test;

    %branch = 2;
    %level = 12 - 6;
    %dict = kmeans_dict(cell2mat(ds(train_idx)), branch, level);

    %% Encoding with codebook
    %%bow = bow_encode(dict, ds);
    %llc = llc_encode(dict, ds);

    %% Approximated chi-square kernel mapping
    %%encode = vl_homkermap(llc, 3, 'kernel', 'kchi2', 'gamma', 1.0);
    %encode = llc;

    %% Evaluate with linear svm
    %train_inst = sparse(encode(:, train_idx));
    %test_inst = sparse(encode(:, test_idx));
    %model = train(double(label(train_idx)), train_inst, '-c 1 -q', 'col');
    %predict(double(label(test_idx)), test_inst, model, '', 'col');

    % -------------------------------------------------------------------------
    %  Sparse Coding with SPAMS
    % -------------------------------------------------------------------------

    %for cv = 1:length(folds)
    %    train_idx = folds(cv).train;
    %    test_idx = folds(cv).test;

    %    dict_param = struct('K', 1024 / 4, 'lambda', 0.25, 'lambda2', 0, ...
    %                        'iter', 1000 / 2, 'mode', 2, 'modeD', 0, ...
    %                        'modeParam', 0, 'clean', true, 'numThreads', 4, ...
    %                        'verbose', false);
    %    dict = sparse_coding_dict(double(cell2mat(ds(train_idx))), dict_param);
    %    encode = sc_encode(dict, ds, dict_param);

    %    % Approximated chi-square kernel mapping
    %    encode = vl_homkermap(encode, 3, 'kernel', 'kchi2', 'gamma', 1);

    %    % Evaluate with linear svm
    %    train_inst = sparse(encode(:, train_idx));
    %    test_inst = sparse(encode(:, test_idx));
    %    model = train(double(label(train_idx)), train_inst, '-c 1 -q', 'col');
    %    predict(double(label(test_idx)), test_inst, model, '', 'col');
    %end

end

% ----------------------------------------------------------------------------
%  Various Helper function
% ----------------------------------------------------------------------------

function setup_3rdparty(root_dir)
    % Add libsvm, liblinear, vlfeat library path
    run(fullfile(root_dir, 'vlfeat/toolbox/vl_setup'));
    addpath(fullfile(root_dir, 'liblinear/matlab'));
    addpath(fullfile(root_dir, 'libsvm/matlab'));

    % Add SPAMS(SPArse Modeling Software) path
    addpath(fullfile(root_dir, 'spams-matlab/test_release'));
    addpath(fullfile(root_dir, 'spams-matlab/src_release'));
    addpath(fullfile(root_dir, 'spams-matlab/build'));
end

function [prefix, label, path] = parse_list(image_list)
    fd = fopen(image_list);
    raw = textscan(fd, '%s %d');
    fclose(fd);

    [path, label] = raw{:};
    [~, prefix, ~] = fileparts(image_list);
end

function image = read_image(path)
    norm_size = [256, 256];

    % TODO: Check if image is valid 3-channel image
    raw_image = imread(path);
    image = normalize_image(raw_image, norm_size);
end

function norm_image = normalize_image(image, norm_size, crop)
    if nargin < 3, crop=true; end

    if not(crop)
        norm_image = imresize(image, norm_size);
    else
        [height, width, channel] = size(image);
        scale = max(norm_size./[height, width])+eps;
        offset = floor(([height width]*scale - norm_size)/2);
        x = offset(2)+1:offset(2)+norm_size(2);
        y = offset(1)+1:offset(1)+norm_size(1);
        resized_image = imresize(image, scale);
        norm_image = resized_image(y, x, :);
    end
end

function folds = cross_validation(label, num_fold)
    folds(1:num_fold) = struct('train', [], 'test', []);
    categories = unique(label);
    for c = 1:length(categories)
        % Select particular category
        list = find(label == categories(c));
        len = length(list);

        % Calculate #test_case on each fold, exactly cover all instances
        sample_fold = randsample(num_fold, mod(len, num_fold));
        test_nums(1:num_fold) = floor(len/num_fold);
        test_nums(sample_fold) = floor(len/num_fold)+1;
        test_nums = test_nums - (test_nums==len);  % Ensure #train_instance > 0

        % Distribute all instances to training set and testing set
        list = list(randperm(len));
        for v = 1:num_fold
            test_list = list(1:test_nums(v));
            train_list = list(test_nums(v)+1:end);

            folds(v).train = [folds(v).train; train_list];
            folds(v).test = [folds(v).test; test_list];
            list = [train_list; test_list];
        end
    end
end

% ----------------------------------------------------------------------------
%  Extract Various Descriptors
% ----------------------------------------------------------------------------

function ds = extract_descriptor(path, ds_type)
    ds = cell(1, length(path));
    for idx = 1:length(path)
        image = read_image(path{idx});

        switch ds_type

            case 'sift'
                gray_image = single(rgb2gray(image));
                ds{idx} = get_sift(gray_image);

            case 'lbp'
                gray_image = rgb2gray(im2single(image));
                ds{idx} = get_pyramid_lbp(gray_image);

                % Ignore spatial and scale information
                ds{idx} = cellfun(@(x) {reshape(x, [], size(x, 3))'}, ds{idx});
                ds{idx} = cell2mat(ds{idx});
                ds{idx} = uint8(round(sqrt(ds{idx}) * 255));

            case 'hog'
                %ds{idx} = get_hog(single(image));
                %ds{idx} = reshape(ds{idx}, [], size(ds{idx}, 3))';

            case 'phow'
                ds{idx} = get_phow(im2single(image));

            otherwise
                fprintf(1, 'Wrong descriptor name.');
                return;
        end
    end
end


function sift = extract_sift(path)
    sift = cell(1, length(path));
    for idx = 1:length(path)
        image = read_image(path{idx});
        image = vl_xyz2lab(vl_rgb2xyz(im2single(image)), 'd50');
        gray_image = single(image(:, :, 1) / 100);

        % Extract SIFT of gray image
        [fs, ds] = vl_sift(gray_image);
        sift{idx} = ds;
    end
end

function lbp = extract_lbp(path, level, scale);
    lbp = cell(1, length(path));
    for idx = 1:length(path)
        image = im2single(read_image(path{idx}));

        % Extract descriptor on scale space
        lbp{idx} = get_color_lbp(image);
        blur_kernel = fspecial('gaussian', [9 9], 1.6);
        for lv = 2:level
            image = imfilter(image, blur_kernel, 'symmetric');
            image = imresize(image, scale);
            lbp{idx} = [lbp{idx} get_color_lbp(image)];
        end

        % Ignore spatial and scale information
        num_channel = size(lbp{idx}, 1);
        lbp{idx} = cellfun(@(x) {reshape(x, [], 58)'}, lbp{idx});
        lbp{idx} = cell2mat(lbp{idx});
    end
end

function lbp = get_color_lbp(image)
    image = rgb2lab(image);

    lbp = cell(size(image, 3), 1);
    for ch = 1:size(image, 3)
        lbp{ch} = get_lbp(image(:, :, ch));
    end
end

function lbp = get_lbp(image)
    cell_size = 16;
    window_size = 2;

    lbp_cell = vl_lbp(image, cell_size) .^ 2;
    lbp = zeros(size(lbp_cell) - [window_size - 1, window_size - 1, 0]);
    for x = 1:size(lbp_cell, 2) - window_size + 1
        for y = 1:size(lbp_cell, 1) - window_size + 1
            y_to = y + window_size - 1;
            x_to = x + window_size - 1;

            lbp_block = lbp_cell(y:y_to, x:x_to, :);
            lbp_block = sum(reshape(lbp_block, [], size(lbp_block, 3)));
            lbp(x, y, :) = lbp_block / sum(lbp_block);
        end
    end
end

function









function ds = get_hog(image)
    cell_size = 16;
    ds = vl_hog(image, cell_size, 'numOrientations', 64);
end

function ds = get_phow(image)
    [fs, ds] = vl_phow(image, 'Color', 'gray', 'Sizes', [12], ...
                       'Step', 16, 'WindowSize', 2, 'Magnif', 6);
    %[fs, ds] = vl_phow(image, 'Color', 'gray', 'Sizes', [8 12 16], ...
    %                   'Step', 8, 'WindowSize', 2, 'Magnif', 6);
end

% ----------------------------------------------------------------------------
%  Generate a descriptor dictionary
% ----------------------------------------------------------------------------

function dict = kmeans_dict(vocab, branch, level)
    leaves = branch ^ level;

    tree = vl_hikmeans(vocab, branch, leaves, 'Method', 'lloyd', 'MaxIters', 400);
    dict = get_leaves_center(tree);
end

function centers = get_leaves_center(tree)
    if tree.depth == 1
        centers = tree.centers;
    else
        centers = [];
        queue = tree.sub;
        while ~isempty(queue)
            if isempty(queue(1).sub)
                centers = [centers queue(1).centers];
            else
                queue = [queue queue(1).sub];
            end
            queue(1) = [];
        end
    end
end

function dict = sparse_coding_dict(vocab, dict_param)
    % Rescale for avoiding numerical difficulty
    vocab = vocab / 255.0;

    % Generate sparse coding basis
    dict = mexTrainDL(vocab, dict_param);

    % Rescale to original range
    dict = dict * 255.0;
end

% ----------------------------------------------------------------------------
%  Descriptor Encoding
% ----------------------------------------------------------------------------

function bow = bow_encode(dict, vocabs)
    dict_size = size(dict, 2);

    bow = zeros(dict_size, length(vocabs));
    for idx = 1:length(vocabs)
        asgn = vl_ikmeanspush(vocabs{idx}, dict);
        hist = vl_ikmeanshist(dict_size, asgn);
        bow(:, idx) = double(hist) / sum(hist);
        %bow(:, idx) = double(hist) / norm(hist);
    end
end

function sc = sc_encode(dict, vocabs, param)
    dict = dict / 255.0;
    sc = zeros(size(dict, 2), length(vocabs));
    for idx = 1:length(vocabs)
        vocab = double(vocabs{idx}) / 255.0;
        alpha = mexLasso(vocab, dict, param);

        % Pooling & normalization
        sc(:, idx) = mean(alpha, 2);
        %sc(:, idx) = max(alpha, [], 2);
        sc(:, idx) = sc(:, idx) / norm(sc(:, idx));
        %sc(:, idx) = sc(:, idx) / sum(sc(:, idx));
    end
end

function llc = llc_encode(dict, vocabs)
    dict = double(dict) / 255.0;
    llc = zeros(size(dict, 2), length(vocabs));
    for idx = 1:length(vocabs)
        x = double(vocabs{idx}) / 255.0;

        % Exactly solution of LLC
        %sigma = 1.0;
        %lambda = 1.0;
        %llc_coeff = llc_exact(dict, x, sigma, lambda);

        % Approximate solution of LLC
        knn = 5;
        llc_coeff = llc_approx(dict, x, knn);

        % Pooling & normalization
        llc(:, idx) = mean(llc_coeff, 2);
        %llc(:, idx) = max(llc_coeff, [], 2);
        llc(:, idx) = llc(:, idx) / norm(llc(:, idx));
        %llc(:, idx) = llc(:, idx) / sum(llc(:, idx));
    end
end

function llc = llc_exact(B, X, sigma, lambda)
    x_num = size(X, 2);
    b_num = size(B, 2);

    llc = zeros(b_num, x_num);
    for idx = 1:size(X, 2)
        xi = X(:, idx);
        di = exp(vl_alldist2(B, xi, 'L2') / sigma);
        di = di / max(di);

        z = B - repmat(xi, 1, b_num);                % Shift properties
        Ci = z' * z;                                 % Local covariance
        Ci = Ci + eye(b_num) * trace(Ci) * 1e-4;     % Regularization
        ci = (Ci + lambda * diag(di .* di)) \ ones(b_num, 1); 
        llc(:, idx) = ci / sum(ci);
    end
end

function llc = llc_approx(B, X, knn)
    x_num = size(X, 2);
    b_num = size(B, 2);

    kd_tree = vl_kdtreebuild(B);
    nearest_neighbors = vl_kdtreequery(kd_tree, B, X, 'NumNeighbors', knn);
    llc = zeros(b_num, x_num);
    for idx = 1:size(X, 2)
        xi = X(:, idx);
        nn = nearest_neighbors(:, idx);

        z = B(:, nn) - repmat(xi, 1, knn);   % Shift properties
        C = z' * z;                          % Local covariance
        C = C + eye(knn) * trace(C) * 1e-4;  % Regularization
        w = C \ ones(knn, 1);

        llc(nn, idx) = w / sum(w);
    end
end

% ----------------------------------------------------------------------------
%  
% ----------------------------------------------------------------------------

