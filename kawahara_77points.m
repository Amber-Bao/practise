% 主程序部分 (脚本代码)，保存为 tijipin.m
% 定义输入和输出文件
wav_file = '/Users/baopinghong/Desktop/在写中：温州鼓词/正式实验/鼓词方言/方言1生男女_L.wav'; % 替换为你的实际WAV文件路径
textgrid_file = '/Users/baopinghong/Desktop/在写中：温州鼓词/正式实验/鼓词方言/方言1生男女_L.TextGrid'; % 替换为你的实际TextGrid文件路径
output_file = '/Users/baopinghong/Desktop/在写中：温州鼓词/正式实验/鼓词方言/output_pitch_data_77_points.csv'; % 替换为输出CSV文件路径

% 检查输入的音频文件是否存在
if ~isfile(wav_file)
    error('音频文件未找到，请检查文件路径：%s', wav_file);
end

% 读取音频文件
[audio_data, fs] = audioread(wav_file); % fs 是采样率

% 使用 simpleTextGridParser 函数读取 TextGrid 文件
tg = simpleTextGridParser(textgrid_file);  % 传递textgrid_file路径参数

% 使用 Tone_Section 作为层名称
tier_name = 'Tone_Section';  % 替换为有效字段名
if ~isfield(tg, tier_name)
    error('Tier not found in TextGrid file.');
end

tier_intervals = tg.(tier_name).intervals;

% 初始化存储提取结果的表
results = struct('label_name', {}, 'duration', {}, 'pitch_values', {});  % 使用结构体数组

% pitch 函数的最小窗口长度（基于 fs 计算）
min_window_length = round(fs * 0.052);  % 确保每个片段至少 52ms

% 遍历每个标注段，提取基频信息
for i = 1:length(tier_intervals)
    % 获取当前标注段的起止时间
    start_time = tier_intervals{i}.xmin;
    end_time = tier_intervals{i}.xmax;
    
    % 获取标注段名称
    label_name = tier_intervals{i}.text;
    
    % 计算当前标注段的时长
    duration = end_time - start_time;
    
    % 如果标注段不为空，提取基频
    if ~isempty(label_name) && duration > 0
        % 计算等比例的77个时间点
        num_points = 77;
        time_points = linspace(start_time, end_time, num_points);
        
        % 初始化存储基频的向量
        pitch_values = NaN(1, num_points);
        
        % 遍历时间点，提取每个点的基频
        for j = 1:num_points
            t = time_points(j);
            
            % 确保时间点在音频范围内
            if t < length(audio_data) / fs
                % 计算采样点，确保是正整数，并且不超出音频数据的范围
                start_sample = max(1, round(t * fs));  % 确保 start_sample 不为 0 或负数
                end_sample = min(length(audio_data), start_sample + min_window_length - 1);  % 确保 end_sample 不超出音频范围
                
                if end_sample > start_sample
                    % 提取音频片段并计算基频，使用默认方法以提高兼容性
                    segment = audio_data(start_sample:end_sample);
                    pitch_val = kjp_MulticueF0v14(segment, fs); % 调用 pitch 函数提取基频，使用默认方法
                    pitch_values(j) = pitch_val(1); % 存储提取的基频值
                end
            end
        end
        
        % 将标注段名称、时长和基频数据存储到结构体数组中
        results(end+1).label_name = label_name;  % 添加标注段名称
        results(end).duration = duration;  % 添加时长
        results(end).pitch_values = pitch_values;  % 添加基频数据
    end
end

% 写入输出文件
fid = fopen(output_file, 'w'); % 打开文件进行写入
if fid == -1
    error('无法打开输出文件：%s', output_file);
end

header = [{'标注段名称', '时长'}, strcat('P', arrayfun(@num2str, 1:77, 'UniformOutput', false))]; % 表头包括 77 个基频点
fprintf(fid, '%s,', header{:});
fprintf(fid, '\n');

% 遍历结果并写入文件
for i = 1:length(results)
    % 如果 results 是一个结构体数组，使用点运算符
    fprintf(fid, '%s,%f,', results(i).label_name, results(i).duration);
    
    % 将基频值以逗号分隔写入
    fprintf(fid, '%f,', results(i).pitch_values);  % pitch_values 是一个普通数组
    fprintf(fid, '\n');
end

fclose(fid);

%----------------------------
% simpleTextGridParser 函数定义 (放在同一文件的底部)
%----------------------------
function tg = simpleTextGridParser(filename)
    fid = fopen(filename, 'r');
    if fid == -1
        error('无法打开文件：%s', filename);
    end
    tg = struct();
    currentTier = '';
    
    % 初始化变量
    xmin = [];
    xmax = [];
    text = '';
    
    while ~feof(fid)
        line = fgetl(fid);
        
        if contains(line, 'name = ')
            tierName = extractBetween(line, '"', '"');
            currentTier = strrep(tierName{1}, ' ', '_');  % 将空格替换为下划线
            
            % 如果层名称是“声调段”，将其转换为英文字段名
            if strcmp(currentTier, '声调段')
                currentTier = 'Tone_Section';  % 替换为有效字段名
            end
            
            disp(['Found tier: ', currentTier]);  % 输出发现的层名称
            tg.(currentTier).intervals = {};  % 初始化当前层的间隔结构
        
        elseif contains(line, 'xmin = ')
            xmin = str2double(extractAfter(line, '= '));
            
        elseif contains(line, 'xmax = ')
            xmax = str2double(extractAfter(line, '= '));
            
        elseif contains(line, 'text = ')
            text = extractBetween(line, '"', '"');
            
            % 检查当前层和间隔数据是否有效
            if ~isempty(currentTier) && ~isempty(xmin) && ~isempty(xmax) && ~isempty(text)
                % 添加间隔到当前层
                tg.(currentTier).intervals{end+1} = struct('xmin', xmin, 'xmax', xmax, 'text', text{1});
                
                % 重置变量
                xmin = [];
                xmax = [];
                text = '';
            else
                disp('Skipping invalid interval due to missing data');
            end
        end
    end
    
    fclose(fid);
end
