clear
close all

%[source,fs] = audioread('../../Audio/SheIsMySin.wav');      % Read
                                                            % source
[source,fs] = audioread('test.wav');
x = source(:,1);                                % Select a channel
L = size(x,1);                                  % Audio length

blockLen = fs*5;                                % Block length
% blockLen = L;
blockNum = ceil(L/blockLen);                    % Block number
x = [x', zeros(1, blockNum*blockLen-L)]';       % Zero padding

N = 1024;                                       % N of FFT
N2 = ceil((N+1)/2);                             % Half N
H = floor(N/2);                                 % Hop size
F = ceil((blockLen-N)/H);                       % No. of frames

stopconv = 40;      % stopping criterion (can be adjusted)
niter = 2000;       % maximum number of iterations (can be adjusted)
r = 3;              % number of desired factors (rank of the
                    % factorization)
verbose = 1;        % prints iteration count and changes in
                    % connectivity matrix elements unless verbose is 0 

% for i=1:blockNum
for i=1:1    % use the first block for now
    block = x((i-1)*blockLen+1 : i*blockLen);
    X = spectrogram(block,hann(N),N-H,N,fs);        % STFT
    M = abs(X);                                     % Spectrum Magnitude
    P = unwrap(angle(X));                           % Spectrum Phase
    
    cons=zeros(F,F);
    consold=cons;
    inc=0;
    j=0;
    
    %% initialize random w and h
    rng('shuffle');
    w=rand(N2,r);
    h=rand(r,F);

    for i=1:niter
        %% divergence-reducing NMF iterations
        x1=repmat(sum(w,1)',1,F);
        h=h.*(w'*(M./(w*h)))./x1;
        x2=repmat(sum(h,2)',N2,1);
        w=w.*((M./(w*h))*h')./x2;
        
        %% test convergence every 10 iterations
        if(mod(i,10)==0)  
            j=j+1;
            
            % adjust small values to avobd undeflow
            h=max(h,eps);w=max(w,eps);
            
            % construct connectivity matrix
            [y,index]=max(h,[],1);   %find largest factor
            mat1=repmat(index,F,1);  % spread index down
            mat2=repmat(index',1,F); % spread index right
            cons=mat1==mat2;
            
            if(sum(sum(cons~=consold))==0) % connectivity matrix has not changed
                inc=inc+1;                     %accumulate count 
            else
                inc=0;                         % else restart count
            end
            if verbose                     % prints number of changing elements 
                fprintf('\t%d\t%d\t%d\n',i,inc,sum(sum(cons~=consold))), 
            end
            
            if(inc>stopconv)
                break,                % assume convergence is connectivity stops changing 
            end 
            
            consold=cons;
        end
    end
end


%% Reconstruct audio from basis

% Overlap-add synthesis
R = w * h;                             % Magnitude
Z = R .* exp(1i * P);                  % Reconstructed complex number
Z = [Z; conj(Z(end-1:-1:2, :))];       % Complete the spectrogram
xr = zeros(1, N+(F-1)*H);              % Initialize reconstructed signal
sw = blackmanharris(N, 'periodic');    % Synthesis window
for k = 1:F
    xi = ifft(Z(:,k), 'symmetric');
    % overlap-add
    xr((k-1)*H+1 : (k-1)*H+N) = xr((k-1)*H+1 : (k-1)*H+N) + (xi.*sw)';
end
xr = xr.*H/sum(sw.^2);      % Normalization

outputAudio = 'reconstruction_all.wav';
wavwrite(xr,fs,outputAudio);

for j = 1:r
    R = w(:,j) * h(j,:);                   % Magnitude
    Z = R .* exp(1i * P);                  % Reconstructed complex number
    Z = [Z; conj(Z(end-1:-1:2, :))];       % Complete the spectrogram
    xr = zeros(1, N+(F-1)*H);              % Initialize reconstructed signal
    sw = blackmanharris(N, 'periodic');    % Synthesis window
    for k = 1:F
        xi = ifft(Z(:,k), 'symmetric');
        % overlap-add
        xr((k-1)*H+1 : (k-1)*H+N) = xr((k-1)*H+1 : (k-1)*H+N) + (xi.*sw)';
    end
    xr = xr.*H/sum(sw.^2);      % Normalization

    outputAudio = ['reconstruction_basis',num2str(j),'.wav'];
    wavwrite(xr,fs,outputAudio);
end


%% Plot results
% plot original spectrogram
figure(1);
imagesc((1:F)*H/fs, fs/N*(1:N2), log(M)); % plot the log spectrum
set(gca,'YDir', 'normal'); % flip the Y Axis so lower frequencies
                           % are at the bottom
title 'Original Spectrogram';
xlabel('Time (s)');
ylabel('Frequency (Hz)');

% plot basis and activation
figure(2);
subplot(121);
imagesc(1:r, 1:N2, log(w)); % plot the log spectrum
set(gca,'YDir', 'normal'); % flip the Y Axis so lower frequencies
                           % are at the bottom
colorbar();
title 'Basis';
xlabel('r');
ylabel('Frequency (Hz)');

subplot(122);
imagesc((1:F)*H/fs, 1:r, log(h)); % plot the log spectrum
set(gca,'YDir', 'normal'); % flip the Y Axis so lower frequencies
                           % are at the bottom
colorbar();
title 'Activition';
xlabel('Time (s)');
ylabel('H');

% plot reconstruction of each basis
figure(3);
for k = 1:r
    subplot(r, 1, k);
    imagesc((1:F)*H/fs, fs/N*(1:N2), log(w(:, k) * h(k, :))); % plot the log spectrum
    set(gca,'YDir', 'normal'); % flip the Y Axis so lower frequencies
                               % are at the bottom
    title(['Basis ', num2str(k), ' Reconstruction']);
    xlabel('Time (s)');
    ylabel('Frequency (Hz)');
end

% plot reconstruction of all basis
figure(4);
imagesc((1:F)*H/fs, fs/N*(1:N2), log(w * h)); % plot the log spectrum
set(gca,'YDir', 'normal'); % flip the Y Axis so lower frequencies
                           % are at the bottom
title(['Reconstruction All']);
xlabel('Time (s)');
ylabel('Frequency (Hz)');
