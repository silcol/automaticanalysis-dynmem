/*=========================================================================

  Program:   Insight Segmentation & Registration Toolkit
  Module:    $RCSfile: itkAtroposSegmentationImageFilter.h,v $
  Language:  C++
  Date:      $Date: $
  Version:   $Revision: $

  Copyright (c) Insight Software Consortium. All rights reserved.
  See ITKCopyright.txt or http://www.itk.org/HTML/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notices for more information.

=========================================================================*/
#ifndef __itkAtroposSegmentationImageFilter_h
#define __itkAtroposSegmentationImageFilter_h

#include "itkImageToImageFilter.h"

#include "itkArray.h"
#include "itkBSplineScatteredDataPointSetToImageFilter.h"
#include "itkFixedArray.h"
#include "itkListSample.h"
#include "itkListSampleFunction.h"
#include "itkListSampleToListSampleFilter.h"
#include "itkPointSet.h"
#include "itkVector.h"

#include <algorithm>
#include <vector>
#include <map>
#include <utility>

namespace itk
{

/** \class AtroposSegmentationImageFilter
 * \brief Atropos:  A Priori Classification with Registration Initialized
 *  Template Assistance
 *
 * This filter provides an Expectation-Maximization framework for statistical
 * segmentation where the intensity profile of each class is modeled as a
 * mixture model and spatial smoothness is enforced by an MRF prior.
 *
 * Initial labeling can be performed by otsu thresholding, kmeans clustering,
 * a set of user-specified prior probability images, or a prior label image.
 * If specified, the latter two initialization options are also used as
 * priors in the MRF update step.
 *
 * The assumed labeling is such that classes are assigned consecutive
 * indices 1, 2, 3, etc.  Label 0 is reserved for the background when a
 * mask is specified.
 *
 */

template<class TInputImage, class TMaskImage
  = Image<unsigned char,::itk::GetImageDimension<TInputImage>::ImageDimension>,
  class TClassifiedImage = TMaskImage>
class ITK_EXPORT AtroposSegmentationImageFilter :
    public ImageToImageFilter<TInputImage, TClassifiedImage>
{
public:
  /** Standard class typdedefs. */
  typedef AtroposSegmentationImageFilter                     Self;
  typedef ImageToImageFilter<TInputImage, TClassifiedImage>  Superclass;
  typedef SmartPointer<Self>                                 Pointer;
  typedef SmartPointer<const Self>                           ConstPointer;

  /** Method for creation through the object factory. */
  itkNewMacro( Self );

  /** Run-time type information (and related methods). */
  itkTypeMacro( AtroposSegmentationImageFilter, ImageToImageFilter );

  /** Dimension of the images. */
  itkStaticConstMacro( ImageDimension, unsigned int,
                       TInputImage::ImageDimension );
  itkStaticConstMacro( ClassifiedImageDimension, unsigned int,
                       TClassifiedImage::ImageDimension );
  itkStaticConstMacro( MaskImageDimension, unsigned int,
                       TMaskImage::ImageDimension );

  /** Typedef support of input types. */
  typedef TInputImage                                 ImageType;
  typedef typename ImageType::PixelType               PixelType;
  typedef TMaskImage                                  MaskImageType;
  typedef typename MaskImageType::PixelType           MaskLabelType;
  typedef TClassifiedImage                            ClassifiedImageType;
  typedef typename ClassifiedImageType::PixelType     LabelType;

  /** Some convenient typedefs. */
  typedef float                                       RealType;
  typedef Image<RealType,
    itkGetStaticConstMacro( ImageDimension )>         RealImageType;
  typedef FixedArray<unsigned,
    itkGetStaticConstMacro( ImageDimension )>         ArrayType;

  /** Mixture model component typedefs */
  typedef Array<RealType>                             MeasurementVectorType;
  typedef typename Statistics::ListSample
    <MeasurementVectorType>                           SampleType;
  typedef SmartPointer<SampleType>                    SamplePointer;
  typedef Statistics::ListSampleFunction
    <SampleType, RealType, RealType>                  LikelihoodFunctionType;
  typedef typename LikelihoodFunctionType::Pointer    LikelihoodFunctionPointer;
  typedef typename LikelihoodFunctionType::
    WeightArrayType                                   WeightArrayType;

  /** Outlier handling typedefs */
  typedef Statistics::ListSampleToListSampleFilter
    <SampleType, SampleType>                          OutlierHandlingFilterType;

  /** B-spline fitting typedefs */
  typedef Vector<RealType, 1>                         ScalarType;
  typedef Image<ScalarType,
    itkGetStaticConstMacro( ImageDimension )>         ScalarImageType;
  typedef PointSet<ScalarType,
    itkGetStaticConstMacro( ImageDimension )>         PointSetType;
  typedef BSplineScatteredDataPointSetToImageFilter
    <PointSetType, ScalarImageType>                   BSplineFilterType;
  typedef typename
    BSplineFilterType::PointDataImageType             ControlPointLatticeType;
  typedef std::vector<typename
    ControlPointLatticeType::Pointer>                 ControlPointLatticeContainerType;

  /** Initialization typedefs */
  enum InitializationStrategyType
    { Random, KMeans, Otsu, PriorProbabilityImages, PriorLabelImage };

  typedef std::pair<RealType, RealType>               LabelParametersType;
  typedef std::map<LabelType, LabelParametersType>    LabelParameterMapType;

  /** ivars Set/Get functionality */

  itkSetClampMacro( NumberOfClasses, unsigned int, 2,
    NumericTraits<LabelType>::max() );
  itkGetConstMacro( NumberOfClasses, unsigned int );

  itkSetMacro( MaximumNumberOfIterations, unsigned int );
  itkGetConstMacro( MaximumNumberOfIterations, unsigned int );

  itkSetMacro( ConvergenceThreshold, RealType );
  itkGetConstMacro( ConvergenceThreshold, RealType );

  itkGetConstMacro( CurrentConvergenceMeasurement, RealType );

  itkGetConstMacro( ElapsedIterations, unsigned int );

  itkSetMacro( MRFSmoothingFactor, RealType );
  itkGetConstMacro( MRFSmoothingFactor, RealType );

  itkSetMacro( MRFRadius, ArrayType );
  itkGetConstMacro( MRFRadius, ArrayType );

  itkSetMacro( InitializationStrategy, InitializationStrategyType );
  itkGetConstMacro( InitializationStrategy, InitializationStrategyType );

  itkSetMacro( SplineOrder, unsigned int );
  itkGetConstMacro( SplineOrder, unsigned int );

  itkSetMacro( NumberOfLevels, ArrayType );
  itkGetConstMacro( NumberOfLevels, ArrayType );

  itkSetMacro( NumberOfControlPoints, ArrayType );
  itkGetConstMacro( NumberOfControlPoints, ArrayType );

  itkSetMacro( MinimizeMemoryUsage, bool );
  itkGetConstMacro( MinimizeMemoryUsage, bool );
  itkBooleanMacro( MinimizeMemoryUsage );

  void SetMaskImage( const MaskImageType * mask );
  const MaskImageType * GetMaskImage() const;

  itkSetClampMacro( PriorProbabilityWeight, RealType, 0.0, 1.0 );
  itkGetConstMacro( PriorProbabilityWeight, RealType );

  void SetAdaptiveSmoothingWeight( unsigned int idx, RealType weight )
    {
    RealType clampedWeight = vnl_math_min( NumericTraits<RealType>::One,
      vnl_math_max( NumericTraits<RealType>::Zero, weight ) );
    /**
     * Clamp values between 0 and 1.  Also, index [0] corresponds to the
     * input image and [1]...[n], correspond to the auxiliary images.
     */
    if( idx >= this->m_AdaptiveSmoothingWeights.size() )
      {
      this->m_AdaptiveSmoothingWeights.resize( idx + 1 );
      this->m_AdaptiveSmoothingWeights[idx] = clampedWeight;
      this->Modified();
      }
    if( this->m_AdaptiveSmoothingWeights[idx] != weight )
      {
      this->m_AdaptiveSmoothingWeights[idx] = clampedWeight;
      this->Modified();
      }
    }
  RealType GetAdaptiveSmoothingWeight( unsigned int idx )
    {
    /**
     * [0] corresponds to the input image and [1]...[n], correspond to
     * the auxiliary images.
     */
    if( idx < this->m_AdaptiveSmoothingWeights.size() )
      {
      return this->m_AdaptiveSmoothingWeights[idx];
      }
    }

  void SetPriorLabelParameterMap( LabelParameterMapType m )
    {
    this->m_PriorLabelParameterMap = m;
    this->Modified();
    }
  void GetPriorLabelParameterMap()
    {
    return this->m_PriorLabelParameterMap;
    }

  /**
   * Prior probability images (numbered between 1,...,numberOfClasses)
   */
  void SetPriorProbabilityImage(
    unsigned int whichClass, const RealImageType * prior );
  const RealImageType *
    GetPriorProbabilityImage( unsigned int whichClass ) const;

  void SetPriorLabelImage( const ClassifiedImageType * prior );
  const ClassifiedImageType * GetPriorLabelImage() const;

  /**
   * Auxiliary images (numbered between 1,...,n)
   */
  void SetIntensityImage( unsigned int which, const ImageType * image );
  const ImageType * GetIntensityImage( unsigned int which ) const;

  /**
   * Euclidean distance uses Maurer to calculate the distance transform image.
   * Otherwise use the fast marching filter.  The former option is faster but it
   * for non-Euclidean shapes (such as the cortex), it might be more accurate
   * to use the latter option.
   */
  itkSetMacro( UseEuclideanDistanceForPriorLabels, bool );
  itkGetConstMacro( UseEuclideanDistanceForPriorLabels, bool );
  itkBooleanMacro( UseEuclideanDistanceForPriorLabels );

  itkSetObjectMacro( OutlierHandlingFilter, OutlierHandlingFilterType );
  itkGetObjectMacro( OutlierHandlingFilter, OutlierHandlingFilterType );

  void SetLikelihoodFunction( unsigned int n, LikelihoodFunctionType *prob )
    {
    if( n < this->m_MixtureModel.size() && this->m_MixtureModel[n] != prob )
      {
      this->m_MixtureModel[n] = prob;
      this->Modified();
      }
    else if( n >= this->m_MixtureModel.size() )
      {
      this->m_MixtureModel.resize( n + 1 );
      this->m_MixtureModel[n] = prob;
      this->Modified();
      }
    }

  LikelihoodFunctionType * GetLikelihoodFunction( unsigned int n )
    {
    if( n < this->m_MixtureModel.size() )
      {
      return this->m_MixtureModel[n].GetPointer();
      }
    else
      {
      return NULL;
      }
    }

  typename RealImageType::Pointer
    GetPosteriorProbabilityImage( unsigned int );
  typename RealImageType::Pointer
    CalculateSmoothIntensityImageFromPriorProbabilityImage(
    unsigned int, unsigned int );
  typename RealImageType::Pointer
    GetDistancePriorProbabilityImageFromPriorLabelImage( unsigned int );
  typename SampleType::Pointer GetScalarSamples( unsigned int );

#ifdef ITK_USE_CONCEPT_CHECKING
  /** Begin concept checking */
  itkConceptMacro( SameDimensionCheck1,
    ( Concept::SameDimension<ImageDimension,
    ClassifiedImageDimension> ) );
  itkConceptMacro( SameDimensionCheck2,
    ( Concept::SameDimension<ImageDimension,
    MaskImageDimension> ) );
  /** End concept checking */
#endif

protected:
  AtroposSegmentationImageFilter();
  ~AtroposSegmentationImageFilter();

  void PrintSelf( std::ostream& os, Indent indent ) const;

  void GenerateData();

private:
  AtroposSegmentationImageFilter(const Self&); //purposely not implemented
  void operator=(const Self&); //purposely not implemented

  void NormalizePriorProbabilityImages();

  void GenerateInitialClassLabeling();
  void GenerateInitialClassLabelingWithOtsuThresholding();
  void GenerateInitialClassLabelingWithKMeansClustering();
  void GenerateInitialClassLabelingWithPriorProbabilityImages();

  RealType UpdateClassParametersAndLabeling();

  unsigned int                                   m_NumberOfClasses;
  unsigned int                                   m_NumberOfIntensityImages;
  unsigned int                                   m_ElapsedIterations;
  unsigned int                                   m_MaximumNumberOfIterations;
  RealType                                       m_CurrentConvergenceMeasurement;
  RealType                                       m_ConvergenceThreshold;

  MaskLabelType                                  m_MaskLabel;

  std::vector<LikelihoodFunctionPointer>         m_MixtureModel;
  Array<RealType>                                m_MixtureModelProportions;
  InitializationStrategyType                     m_InitializationStrategy;

  typename OutlierHandlingFilterType::Pointer    m_OutlierHandlingFilter;

  ArrayType                                      m_MRFRadius;
  RealType                                       m_MRFSmoothingFactor;

  std::vector<RealType>                          m_AdaptiveSmoothingWeights;
  RealType                                       m_PriorProbabilityWeight;
  LabelParameterMapType                          m_PriorLabelParameterMap;

  unsigned int                                   m_SplineOrder;
  ArrayType                                      m_NumberOfLevels;
  ArrayType                                      m_NumberOfControlPoints;
  std::vector<ControlPointLatticeContainerType>  m_ControlPointLattices;

  typename RealImageType::Pointer                m_SumDistancePriorProbabilityImage;
  typename RealImageType::Pointer                m_SumPosteriorProbabilityImage;
  bool                                           m_MinimizeMemoryUsage;

  bool                                           m_UseEuclideanDistanceForPriorLabels;
  std::vector<typename RealImageType::Pointer>   m_DistancePriorProbabilityImages;
  std::vector<typename RealImageType::Pointer>   m_PosteriorProbabilityImages;

};

} // namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkAtroposSegmentationImageFilter.txx"
#endif

#endif
