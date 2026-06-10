function t_mid = get_frame_times(info)

nFrames = double(info.NumberOfFrames);
dt = nan(nFrames,1);

if isfield(info,'PhaseInformationSequence') && isfield(info,'PhaseVector')

    phaseNames = fieldnames(info.PhaseInformationSequence);

    for p = 1:length(phaseNames)

        phaseInfo = info.PhaseInformationSequence.(phaseNames{p});
        phaseNumber = p;

        framesInThisPhase = info.PhaseVector == phaseNumber;

        if isfield(phaseInfo,'ActualFrameDuration')
            dt(framesInThisPhase) = double(phaseInfo.ActualFrameDuration) / 1000;
        end
    end
end

if any(isnan(dt))
    warning('Frame timing missing. Using 10 sec per frame for missing values.');
    dt(isnan(dt)) = 10;
end

t_mid = cumsum(dt) - dt/2;

end