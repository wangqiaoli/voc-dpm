function labels = rescore_labels(cls, boxes, trainset)
% Get classification training labels for training the context rescoring
% classifier.
%   labels = rescore_labels(cls, boxes, trainset)
%
% Return value
%   labels      Binary labels {-1,+1} for each detection in boxes
%
% Arguments
%   cls         Object class
%   boxes       Detections
%   trainset    Training dataset

conf = voc_config();
cachedir = conf.paths.model_dir;
VOCopts  = conf.pascal.VOCopts;

try
  load([cachedir cls '_rescore_labels_' trainset '_' VOCyear]);
catch
  [gt, npos] = labeldata(cls, trainset);
  [gtids, t] = textread(sprintf(VOCopts.imgsetpath,trainset),'%s %d');
  
  labels = cell(length(gtids),1);   

  L = 0;
  for i = 1:length(gtids)
    L = L + size(boxes{i},1);
  end
  
  detections = zeros(L,7);
  I = 1;
  for i = 1:length(gtids)
    if ~isempty(boxes{i})
      l = size(boxes{i},1);
      % Detection scores
      detections(I:I+l-1,1) = boxes{i}(:,end);
      % Detection windows
      detections(I:I+l-1,2:5) = boxes{i}(:,1:4);
      % The image (i) the detections came from
      detections(I:I+l-1,6) = i;      
      % The index in boxes{i} for each detection
      detections(I:I+l-1,7) = 1:l;      
      labels{i} = zeros(l,1);    
      I = I+l;
    else
      labels{i} = [];
    end
  end
  
  [sc, si] = sort(-detections(:,1));
  ids = detections(si,6);
  idx = detections(si,7);
  BB = detections(si,2:5)';
  
  % Adapted from the VOCdevkit m-file VOCevaldet.m

  % assign detections to ground truth objects
  nd=length(si);
  for d=1:nd
    % find ground truth image
    i=ids(d);
    
    % assign detection to ground truth object if any
    bb=BB(:,d);
    ovmax=-inf;
    for j=1:size(gt(i).BB,2)
      bbgt=gt(i).BB(:,j);
      bi=[max(bb(1),bbgt(1)) ; max(bb(2),bbgt(2)) ; min(bb(3),bbgt(3)) ; min(bb(4),bbgt(4))];
      iw=bi(3)-bi(1)+1;
      ih=bi(4)-bi(2)+1;
      if iw>0 & ih>0                
        % compute overlap as area of intersection / area of union
        ua=(bb(3)-bb(1)+1)*(bb(4)-bb(2)+1)+...
           (bbgt(3)-bbgt(1)+1)*(bbgt(4)-bbgt(2)+1)-...
           iw*ih;
        ov=iw*ih/ua;
        if ov>ovmax
          ovmax=ov;
          jmax=j;
        end
      end
    end
    % assign detection as true positive/don't care/false positive
    if ovmax>=VOCopts.minoverlap
      if ~gt(i).diff(jmax)
        if ~gt(i).det(jmax)
          % True positive
          gt(i).det(jmax)=true;
          labels{i}(idx(d)) = 1;
        else
          % false positive (multiple detection)
          labels{i}(idx(d)) = -1;
        end
      else
        labels{i}(idx(d)) = 1;   % difficult
      end
    else
      % false positive (low overlap)
      labels{i}(idx(d)) = -1;
    end
  end
  save([cachedir cls '_rescore_labels_' trainset '_' VOCyear], 'labels');
end
