function HHP_Feb_14
    %% 0. Program Initialization
    clc; clear;
    
    % Identify and set the primary working directory
    scriptDir = fileparts(mfilename('fullpath'));
    addpath(scriptDir);

    %% 1. Import and Process Heating Load Data
    csvFilePath = fullfile(scriptDir, 'heating_demand_test2.csv');
    data = readtable(csvFilePath, 'VariableNamingRule', 'preserve');
    heating_load = data.("Heating_Load(kW)");
    time_seconds = data.("Time(Seconds)");

    % Remove invalid data points (NaN and Inf values)
    valid_indices = ~isnan(time_seconds) & ~isnan(heating_load) & ...
                    ~isinf(time_seconds) & ~isinf(heating_load);
    time_seconds = time_seconds(valid_indices);
    heating_load = heating_load(valid_indices);

    % Verify time sequence integrity
    if any(diff(time_seconds) <= 0)
        error('Time values must be in ascending order without duplicates.');
    end

    % Generate timeseries object for Simulink input
    Load_timeseries = timeseries(heating_load, time_seconds);
    disp('Heating load data successfully imported and processed.');
    assignin('base', 'Load_timeseries', Load_timeseries);

    %% 2. Configure Simulation Duration
    defaultSimDuration = max(time_seconds);
    fprintf('Available simulation duration: %.2f seconds.\n', defaultSimDuration);

    userSimTime = input('Specify simulation duration in seconds (press Enter to use available duration): ', 's');
    if isempty(userSimTime)
        simDuration = defaultSimDuration;
    else
        simDuration = str2num(userSimTime);  %#ok<ST2NM>
        if isempty(simDuration) || simDuration <= 0
            error('Please enter a positive numerical value for simulation duration.');
        end
    end
    fprintf('Simulation duration set to: %.2f seconds.\n', simDuration);
    simStopTime = num2str(simDuration);

    %% 3. Initialize Simulation Model
    modelName = 'HHP_simulation'; 
    modelPath = fullfile(scriptDir, [modelName, '.slx']);
    load_system(modelPath)

    fprintf('\nSimulation model initialized: %s\n', modelName);

    %% 4. Execute Simulation
    set_param(modelName, 'StopTime', simStopTime);
    set_param(modelName, 'SimulationCommand', 'start');
    
    hWait = waitbar(0, 'Starting simulation...', 'Name', 'Simulation Status');
    simStartTime = tic;
    
    while ~strcmp(get_param(modelName, 'SimulationStatus'), 'stopped')
        currentSimTime = get_param(modelName, 'SimulationTime');
        progress = min(currentSimTime / simDuration, 1);
        elapsed = toc(simStartTime);
        waitbar(progress, hWait, sprintf('Completion: %.1f%%\nElapsed time: %.1f s\nCurrent simulation time: %.1f s', ...
            progress*100, elapsed, currentSimTime));
        pause(0.2);
    end
    close(hWait);

    %% 5. Extract Basic Simulation Results
    try
        logsout = evalin('base', 'logsout');
        disp('Simulation completed successfully. Results available in workspace variable "logsout".');
    catch
        error(['Unable to access simulation results. Please ensure that: \n' ...
               '1. The model is configured to log data to "logsout"\n' ...
               '2. Single simulation output option is disabled']);
    end
    
    % Display available signals
    disp('Available signals in simulation results:');
    signalNames = logsout.getElementNames();
    for i = 1:length(signalNames)
        disp(['  - ', signalNames{i}]);
    end
end