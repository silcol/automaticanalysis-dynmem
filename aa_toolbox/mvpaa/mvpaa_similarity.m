% MVPAA_SIMILARITY - Obtain the similarities for our data points
% Pattern (Volumes * Pattern length)

function Similarity = mvpaa_similarity(aap, Pattern)

% Similaritylate across voxels to find the similarity of voxel patterns
% across conditions.
% Distance metrics are inverted (less negative distances are closer)

switch aap.tasklist.currenttask.settings.similarityMetric
    case 'Pearson'
        % This is *much* faster than corr...
        Similarity = corrcoef(Pattern');
    case 'Spearman'
        % Get Spearman correlations
        Similarity = corr(Pattern', 'type', 'Spearman');
    case 'Euclid'
        % Get Euclidian distance
          if all(isreal(Pattern(:)))
            Similarity = -squareform(pdist(Pattern, 'euclidean'));
        else
            Similarity = -squareform(pdist_complex(Pattern, 'euclidean'));
        end
    case 'sEuclid'
        % Get Euclidian distance (standardised)
          if all(isreal(Pattern(:)))
            Similarity = -squareform(pdist(Pattern, 'seuclidean'));
        else
            Similarity = -squareform(pdist_complex(Pattern, 'seuclidean'));
        end
    case 'Mahalanobis'
        % Get Mahalanobis distance
        dbstop if warning % If matrix is close to singular or badly scaled, we may see NaNs...
        if all(isreal(Pattern(:)))
            Similarity = -squareform(pdist(Pattern, 'mahalanobis'));
        else
            Similarity = -squareform(pdist_complex(Pattern, 'mahalanobis'));
        end
    otherwise
        error('Incorrect metric of (dis)similarity between patterns');
end