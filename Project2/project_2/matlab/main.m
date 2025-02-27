clear;

%% Task 2 - DCT based Image compression
%
x = im2double(imread('peppers512x512.tif'));

%Function definitions
uniform_quantizer = @(x,ssize) round(x/ssize)*ssize;
mse = @(x,y) sum(sum((y-x).^2))/(size(y,1) * size(y,2));
PSNR = @(D) 10*log10(255^2./D);

%DCT-1 and Inverse DCT of 8x8 white image
white_8x8 = ones(8);

ct = dctz(white_8x8); %dctz and idctz work with 8x8 input matrix hardcoded
ict = idctz(ct);

%Process the loaded image block by block

%dct version
% block_ct = blockproc(im,[8 8],@dctz);
% block_ict = blockproc(block_ct,[8 8],@idctz);
%
% figure;
% imshow(block_ct);
% figure
% imshow(block_ict);

%DCT-2
block_dct = blockproc(x,[8 8],@dctz2);
block_idct = blockproc(block_dct,[8 8],@idctz2);

figure;
imshow(x);
title('Original Image peppers 512x512');
figure;
imshow(block_dct);
title('DCT coefficients');
figure;
imshow(block_idct);
title('Reconstruction without quantization');

%reconstructed image error before applying quantization
reconstruction_MSE_without_quantization = mse(block_idct, x)
PSNR(reconstruction_MSE_without_quantization)

%Applying uniform quantizer with step size of 1
ss = 1; %step size
y_coeff = uniform_quantizer(block_dct,ss);

y = blockproc(y_coeff,[8 8], @idctz2);

%reconstructed image error after applying quantization
reconstruction_MSE_with_quantization = mse(y, x)
PSNR(reconstruction_MSE_with_quantization)

% due to quantization errors the output can contain values "<0" and ">1"
% therefore we floor/ceil output range to [0,1] since we are working
% with doubles
y_bound = y;
y_bound( y_bound>1 ) = 1;
y_bound( y_bound<0 ) = 0;
reconstruction_MSE_with_quantization_and_bound = mse(y_bound, x)
PSNR(reconstruction_MSE_with_quantization_and_bound)

figure;
imshow(y);
title('Reconstructed image after quantization with step size 1');

%mse of coeffictients (before, after quatization)
coeffs_mse = mse(block_dct, y_coeff)

% to calculate real PSNR we have to switch back from [0,1] to [0,255] scale
%    we are using y_bound as output (this has values clipped to range [0,1]
y = y_bound;

x255 = round(255*x);
y255 = round(255*y); 

%D = mse(y,x); % PSNR=72dB (for ss=1), where x,y are in range [0,1]
Dist = mse(y255,x255); % PSNR=24dB (for q=1) which is more realistic
PSNR(Dist);


%% Distortion and Bit-rate estimation
%
% TODO: commment why they are the same (orthonormal transform?)
%

%doing this manually is bad, yes.
x = im2double(imread('peppers512x512.tif'));
x = 255*x;
x2 = im2double(imread('boats512x512.tif'));
x2 = 255*x2;
x3 = im2double(imread('harbour512x512.tif'));
x3 = 255*x3;

x_dct = blockproc(x,[8 8],@dctz2);
x2_dct = blockproc(x2,[8 8],@dctz2);
x3_dct = blockproc(x3,[8 8],@dctz2);

ssizes = [1 2 4 8 16 32 64 128 256 512]';
psnrs = zeros(size(ssizes));
rates = zeros(size(ssizes));
i=7;
for i=1:size(ssizes)
    s=ssizes(i);
    y_coeff = uniform_quantizer(x_dct,s);
    y2_coeff = uniform_quantizer(x2_dct,s);
    y3_coeff = uniform_quantizer(x3_dct,s);

    %THIS WAS TO ESTIMATE PSNR FOR SINGLE IMAGE     
%     reconstruction_MSE = mse(x_dct, y_coeff);
%     reconstruction_PSNR = PSNR(reconstruction_MSE);

    %PSNR for 3 images combined
    reconstruction_MSE = mse([x_dct x2_dct x3_dct], [y_coeff, y2_coeff y3_coeff]);
    reconstruction_PSNR = PSNR(reconstruction_MSE);
    psnrs(i) = reconstruction_PSNR;
    y = blockproc(y_coeff,[8 8],@idctz2);
    
    %show image for q=64 
    if(i==7)
        figure;
        imshow(y,[]);
        title('DCT reconstruction with q=64');
    end
    
    y_coeffs = [y_coeff, y2_coeff y3_coeff];
    %calculate rates are hardcoded jbg.
     
    coefs = zeros(8,8,64*64*3); %for each of coeffs 64blocks * 3 images
    for w=1:8
        for h=1:8
            for img=1:3
                index = 1;
                for k=0:63
                    for l=0:63
                        %get only DC coeffs
                        coefs(w,h,64*64*(img-1)+index) = y_coeffs((8*k)+w,img*(8*l)+h);
                        index = index + 1;
                    end
                end
            end
        end
    end
    
    %now calculate R
    H=zeros(8,8);
    for w=1:8
        for h=1:8
            vals = squeeze(coefs(w,h,:));
            p = hist(vals,min(vals):s:max(vals));
            p = p/sum(p);
            
            H(w,h) = -sum(p.*log2(p+eps)); %eps added for log of 0 vals
        end
    end
    
    rates(i) = mean2(H);
    
    %figure;
    %imshow(blockproc(y_coeff,[8 8],@idctz2),[]);
end

H_DCT = H;
figure;
surf(H_DCT);
title('Average entropy of 8x8 DCT block coefficients');
clear H;

figure;
plot(rates, psnrs, '+-', 'linewidth', 2);
title('Performance vs bitrate (DCT)');
grid on;
xlabel('[Bits per pixel] rate');
ylabel('[dB] PSNR');
hold;
%% Task 3
% filters are generated inside FWT2 using the DWTAnalysis and DWTSynthesis
% functions

im = 255*im2double(imread('peppers512x512.tif'));
s = im(1,:);

load db4  
wavelet = db4;  %prototype for the 8-tap daubechies filters
 
figure;
DWT = FWT2(im,wavelet,4);
% Show scale 4 DWT coefficients
imshow(DWT/255);
 
%Uniform Quantization of wavelet transform
Lo_R = wavelet/norm(wavelet);   %reconstruction LPF
Lo_D = wrev(Lo_R);  %decomposition LPF
Hi_R = qmf(Lo_R);   %reconstruction HPF
Hi_D = wrev(Hi_R);  %decomposition HPF
 
[CA,CH,CV,CD] = dwt2(im,Lo_R,Hi_R);
rec1 = idwt2(CA,CH,CV,CD,Lo_D,Hi_D);


% step size for the quantizer, smaller step size is better
stepq = 2.^[0 1 2 3 4 5 6 7 8 9];
step_count = [1:length(stepq)];

% Uniformely quantize values
for k = step_count
        CAq(:,:,k) = uniform_quantizer(CA,stepq(k));
        CHq(:,:,k) = uniform_quantizer(CH,stepq(k));
        CVq(:,:,k) = uniform_quantizer(CV,stepq(k));
        CDq(:,:,k) = uniform_quantizer(CD,stepq(k));
end
% Reconstruct images
for k = step_count
        recq(:,:,k) = idwt2(CAq(:,:,k),CHq(:,:,k),CVq(:,:,k),CDq(:,:,k),Lo_D,Hi_D);
        % compute mse
        mserr(k) = mse(im,recq(:,:,k));
end
 
mserrdb_wav = 10*log10(mserr);
Psnr_wav = PSNR(mserr);

% Compute entropy of each subband

figure;
imshow(recq(:,:,7),[]);
title('DWT reconstruction for q=64');

for k = step_count
    %vectors of wavelet coefficients
    A{k} = reshape(CAq(:,:,k),[1,size(CAq(:,:,k),1)*size(CAq(:,:,k),2)]);
    H{k} = reshape(CHq(:,:,k),[1,size(CHq(:,:,k),1)*size(CHq(:,:,k),2)]);
    V{k} = reshape(CVq(:,:,k),[1,size(CVq(:,:,k),1)*size(CVq(:,:,k),2)]);
    D{k} = reshape(CDq(:,:,k),[1,size(CDq(:,:,k),1)*size(CDq(:,:,k),2)]);
    % compute bins to estimate pdfs
    bins_A{k} = [min(A{k}):stepq(k):max(A{k})];
    bins_H{k} = [min(H{k}):stepq(k):max(H{k})];
    bins_V{k} = [min(V{k}):stepq(k):max(V{k})];
    bins_D{k} = [min(D{k}):stepq(k):max(D{k})];
    % histogram with bins to get pdfs
    pdfA{k} = hist(A{k},bins_A{k})/length(A{k});
    pdfH{k} = hist(H{k},bins_H{k})/length(H{k});
    pdfV{k} = hist(V{k},bins_V{k})/length(V{k});
    pdfD{k} = hist(D{k},bins_D{k})/length(D{k});
    % compute hentropy from pdfs
    enA{k} = -sum(pdfA{k}.*log2(pdfA{k}+eps));
    enH{k} = -sum(pdfH{k}.*log2(pdfH{k}+eps));
    enV{k} = -sum(pdfV{k}.*log2(pdfV{k}+eps));
    enD{k} = -sum(pdfD{k}.*log2(pdfD{k}+eps));
    % total hentropy / average
    en{k} = 0.25*(enA{k}+enH{k}+enV{k}+enD{k});
end
Entropy = cell2mat(en);
 
%use entropy as ideal bit rates per coefficient
rates_wav = Entropy;

figure;
plot(rates_wav, Psnr_wav, '+-', 'linewidth', 2);
title('Performance vs bitrate (DWT)');
grid on;
xlabel('[Bits per pixel] rate');
ylabel('[dB] PSNR');


%plot em together
figure;
plot(rates, psnrs, '+-', 'linewidth', 2);
title('Performance vs bitrate (DCT vs DWT)');
grid on;
xlabel('[Bits per pixel] rate');
ylabel('[dB] PSNR');
hold;
plot(rates_wav, Psnr_wav, '+-', 'linewidth', 2);
legend('DCT','DWT - Daubechies 8 wavelet');
