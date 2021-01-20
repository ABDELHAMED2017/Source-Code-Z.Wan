clear;
flag_save = 1;
%% parameter setting
Lp = 6; %�ྶ��
D_MS = 4.7;   %����x��yά����ͬ
D_BS = 4.7;   %����x��yά����ͬ
ele_max_MS = pi;
azi_max_MS = pi;
ele_max_BS = pi;
azi_max_BS = pi;
N_MS = MY_number_of_antennas_FDLens(D_MS, ele_max_MS, azi_max_MS); %49
N_BS = MY_number_of_antennas_FDLens(D_BS, ele_max_BS, azi_max_BS); %81
N_RF_MS = 4;
N_RF_BS = 4;
Ns = 2;
N_RF_MS_used = N_RF_MS;
N_RF_BS_used = N_RF_BS;
N_MS_block = N_MS/N_RF_MS;
N_BS_block = N_BS/N_RF_BS; 
N_MS_beam = N_MS; %N_beam��ͬʱΪN_RF��N_block�ı���
N_BS_beam = N_BS; %N_beam��ͬʱΪN_RF��N_block�ı���
awgn_en = 1;

%% ���Ԥ�����뱾��ƣ���֤����ض���С��MTC��
F_RF = eye(N_MS);
W_RF = eye(N_BS);
index_F = randperm(N_MS);    % random permutation
index_W = randperm(N_BS);
F_RF = F_RF(:,index_F);
W_RF = W_RF(:,index_W);

F_BB_q = dftmtx(N_RF_MS);
W_BB_q = dftmtx(N_RF_BS);
F_BB_q = F_BB_q(:,1:N_MS_beam/N_MS_block);
W_BB_q = W_BB_q(:,1:N_BS_beam/N_BS_block);
F_BB_MTC = kron(eye(N_MS_block),F_BB_q);
W_BB_MTC = kron(eye(N_BS_block),W_BB_q);

F_MTC = F_RF*F_BB_MTC;
F_MTC = sqrt(N_MS_beam)/norm(F_MTC,'fro')*F_MTC;
W_MTC = W_RF*W_BB_MTC;
W_MTC = sqrt(N_BS_beam)/norm(W_MTC,'fro')*W_MTC;

%% ���ڼ�����
diag_W_MTC = zeros(N_BS*N_BS_beam/N_RF_BS,N_BS_beam);
for nn = 1:N_BS_beam/N_RF_BS
    diag_W_MTC((nn-1)*N_BS+1:nn*N_BS,(nn-1)*N_RF_BS+1:nn*N_RF_BS) = W_MTC(:,(nn-1)*N_RF_BS+1:nn*N_RF_BS);
end

%% ����Ⱥ�Ԥ�ÿռ�
iterMax = 500;
PNR_dBs = -10:-5;
NMSE = zeros(1,length(PNR_dBs));
BER = zeros(1,length(PNR_dBs));
N_bit_per_sym = 6;   % bits number of per symbol
M = 2^N_bit_per_sym; %���ƽ���
N_frame = 1000;

%% Channel Estimation   
for iter = 1:iterMax
    H_up = mmWave_uplink_channel_FDLens(D_MS, D_BS, ele_max_MS, azi_max_MS, ele_max_BS, azi_max_BS, Lp, 0);  
    for i_PNR_dB = 1:length(PNR_dBs)
        tic
        sigma2 = 10^(-(PNR_dBs(i_PNR_dB)/10));
        sigma = sqrt(sigma2);
        N_error_bit = 0;
               
        noise = sigma*(normrnd(0,1,N_BS*N_BS_beam/N_RF_BS,N_MS_beam)+1i*normrnd(0,1,N_BS*N_BS_beam/N_RF_BS,N_MS_beam))/sqrt(2);
        Y_MTC_r = W_MTC'*H_up*F_MTC + awgn_en*diag_W_MTC'*noise;
        y_MTC_r = reshape(Y_MTC_r,N_BS_beam*N_MS_beam,1);  
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Original below
        Q_CSM_MTC_r = kron((F_MTC.'),W_MTC');
        h_up_LS_r = Q_CSM_MTC_r' * y_MTC_r;
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Original above
        
        H_up_LS_r = reshape(h_up_LS_r,N_BS,N_MS);
        
        NMSE_temp = norm(H_up_LS_r - H_up,'fro')^2/norm(H_up,'fro')^2;
        NMSE(i_PNR_dB) = NMSE(i_PNR_dB) + NMSE_temp;
        
        %% find beam and select antenna
        h_est_temp = reshape(H_up_LS_r,N_MS*N_BS,1);
        [~,idx_h] = sort(abs(h_est_temp),'descend');
        idx_sel_ant_MS = [];
        idx_sel_ant_BS = [];
        cnt = 1;
        while(length(idx_sel_ant_MS)~=N_RF_MS_used || length(idx_sel_ant_BS)~=N_RF_BS_used)
            [I,J]=ind2sub(size(H_up_LS_r),idx_h(cnt));
            cnt = cnt + 1;
            if(length(idx_sel_ant_BS) < N_RF_BS_used), idx_sel_ant_BS = union(idx_sel_ant_BS,I); end
            if(length(idx_sel_ant_MS) < N_RF_MS_used), idx_sel_ant_MS = union(idx_sel_ant_MS,J); end
        end        
        
        %% Reduced MIMO
        H_up_reduced = H_up_LS_r(idx_sel_ant_BS,idx_sel_ant_MS);    
        
        %% precoding
        [U, ~, V] = svd(H_up_reduced);
        W = U(:,1:Ns);exp(1i*2*pi*rand(4,2))/2; F = V(:,1:Ns);exp(1i*2*pi*rand(4,2))/2;

        %% BER
        % Create a turbo encoder and decoder pair, where the interleaver indices
        % are supplied by an input argument to the |step| function.
        hTEnc = comm.TurboEncoder('InterleaverIndicesSource','Input port');
        hTDec = comm.TurboDecoder('InterleaverIndicesSource','Input port', ...
            'NumIterations',4);       
        hMod = comm.RectangularQAMModulator('ModulationOrder',M, ...
            'BitInput',true, ...
            'NormalizationMethod','Average power');
        hDemod = comm.RectangularQAMDemodulator('ModulationOrder',M, ...
                'BitOutput',true, ...
                'NormalizationMethod','Average power', ...
                'DecisionMethod','Log-likelihood ratio'); 
        
        % Determine the interleaver indices given the frame length
        intrlvrIndices = randperm(N_frame*N_bit_per_sym);
    
        for ns = 1:Ns   
            % Generate random binary data
            data(ns,:) = randi([0 1],1,N_frame*N_bit_per_sym);
            
            % Turbo encode the data
            encodedData(ns,:) = (step(hTEnc,data(ns,:).',intrlvrIndices)).'; 
            
            % Modulate the encoded data
            modSignal(ns,:) = (step(hMod,(encodedData(ns,:)).')).';
        end
        
        y = W'*(H_up(idx_sel_ant_BS, idx_sel_ant_MS) * F * modSignal + ...
            sigma/sqrt(2)*(normrnd(0,1,N_RF_BS_used,size(modSignal,2)) + 1i*normrnd(0,1,N_RF_BS_used,size(modSignal,2))));

        receivedSignal = (W'*H_up_LS_r(idx_sel_ant_BS, idx_sel_ant_MS) * F) \ y;
        
        for ns = 1:Ns  
            % Demodulate the received signal
            demodSignal(ns,:) = step(hDemod,receivedSignal(ns,:).').';
            
            % Turbo decode the demodulated signal. Because the bit mapping from the
            % demodulator is opposite that expected by the turbo decoder, the
            % decoder input must use the inverse of demodulated signal.
            receivedBits(ns,:) = step(hTDec,-demodSignal(ns,:).',intrlvrIndices).';
        end
        
        Tx_bit = reshape(data, N_frame*Ns*N_bit_per_sym, 1);
        Rx_bit = reshape(receivedBits, N_frame*Ns*N_bit_per_sym, 1);
        
        N_error_bit = sum(Tx_bit ~= Rx_bit) + N_error_bit;
        BER(i_PNR_dB) = BER(i_PNR_dB) + N_error_bit;
        
        toc
        disp(['  fullLS ' num2str(Ns) num2str(N_RF_MS_used) num2str(N_RF_BS_used) ', ' num2str(M) '-QAM, overhead = ' num2str(N_MS_beam) ', SNR = ' num2str(PNR_dBs(i_PNR_dB))...
            ', iter_max = ' num2str(iterMax) ', iter_now = ' num2str(iter) ', NMSE_now = ' num2str(10*log10(NMSE_temp)) 'dB, NMSE_avg = ' num2str(10*log10(NMSE(i_PNR_dB)/iter))...
            'dB, BER_temp = ' num2str(BER(i_PNR_dB)/(iter*N_frame*Ns*N_bit_per_sym)) ', bit_temp = ' num2str(iter*N_frame*Ns*N_bit_per_sym)...
            ', error_bit = ' num2str(N_error_bit)]);
    end
end
NMSE = NMSE/iterMax;
BER = BER/(iterMax*N_frame*Ns*N_bit_per_sym);
disp('Finished all');
if(flag_save)
    save BER_64QAM_fullLS_m10tom5_L6_turbo BER
end
%% Plot
% semilogy(PNR_dBs,BER,'-m^','LineWidth',1.5); grid on;
% xlabel('SNR [dB]'),ylabel('BER')