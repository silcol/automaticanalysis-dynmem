/*=========================================================================

  Program:   Insight Segmentation & Registration Toolkit
  Module:    $RCSfile: itkProbabilisticRegistrationFunction.cxx,v $
  Language:  C++
  Date:      $Date: 2008/11/15 23:46:06 $
  Version:   $Revision: 1.18 $

  Copyright (c) 2002 Insight Consortium. All rights reserved.
  See ITKCopyright.txt or http://www.itk.org/HTML/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even 
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR 
     PURPOSE.  See the above copyright notices for more information.

=========================================================================*/
#ifndef _itkProbabilisticRegistrationFunction_txx_
#define _itkProbabilisticRegistrationFunction_txx_

#include "itkProbabilisticRegistrationFunction.h"
#include "itkExceptionObject.h"
#include "vnl/vnl_math.h"
#include "itkImageFileWriter.h"
#include "itkDiscreteGaussianImageFilter.h"
#include "itkMeanImageFilter.h"
#include "itkMedianImageFilter.h"
#include "itkImageFileWriter.h"
namespace itk {

/*
 * Default constructor
 */
template <class TFixedImage, class TMovingImage, class TDeformationField>
ProbabilisticRegistrationFunction<TFixedImage,TMovingImage,TDeformationField>
::ProbabilisticRegistrationFunction()
{
  m_AvgMag=0;
  m_Iteration=0;
  RadiusType r;
  unsigned int j;
  for( j = 0; j < ImageDimension; j++ )
    {
    r[j] = 2;
    }
  this->SetRadius(r);
  this->m_Energy = 0.0;
  m_TimeStep = 1.0;
  m_DenominatorThreshold = 1e-9;
  m_IntensityDifferenceThreshold = 0.001;
  Superclass::m_MovingImage = NULL;
  m_MetricGradientImage = NULL;
  Superclass::m_FixedImage = NULL;
  m_FixedImageSpacing.Fill( 1.0 );
  m_FixedImageOrigin.Fill( 0.0 );
  m_FixedImageGradientCalculator = GradientCalculatorType::New();
  binaryimage=NULL;
  m_FullyRobust=false;
  m_MovingImageGradientCalculator = GradientCalculatorType::New();

  typename DefaultInterpolatorType::Pointer interp =
    DefaultInterpolatorType::New();

  m_MovingImageInterpolator = static_cast<InterpolatorType*>(
    interp.GetPointer() );

  for (int i=0; i<5; i++) finitediffimages[i]=NULL;

  m_NumberOfHistogramBins=32; 

  m_FixedImageMask=NULL;
  m_MovingImageMask=NULL;

}


/*
 * Standard "PrintSelf" method.
 */
template <class TFixedImage, class TMovingImage, class TDeformationField>
void
ProbabilisticRegistrationFunction<TFixedImage,TMovingImage,TDeformationField>
::PrintSelf(std::ostream& os, Indent indent) const
{
  
  Superclass::PrintSelf(os, indent);
/*
  os << indent << "MovingImageIterpolator: ";
  os << m_MovingImageInterpolator.GetPointer() << std::endl;
  os << indent << "FixedImageGradientCalculator: ";
  os << m_FixedImageGradientCalculator.GetPointer() << std::endl;
  os << indent << "DenominatorThreshold: ";
  os << m_DenominatorThreshold << std::endl;
  os << indent << "IntensityDifferenceThreshold: ";
  os << m_IntensityDifferenceThreshold << std::endl;
*/
}


/*
 * Set the function state values before each iteration
 */
template <class TFixedImage, class TMovingImage, class TDeformationField>
void
ProbabilisticRegistrationFunction<TFixedImage,TMovingImage,TDeformationField>
::InitializeIteration()
{
  typedef ImageRegionIteratorWithIndex<MetricImageType> ittype;
  if( !Superclass::m_MovingImage || !Superclass::m_FixedImage || !m_MovingImageInterpolator )
    {
    itkExceptionMacro( << "MovingImage, FixedImage and/or Interpolator not set" );
    throw ExceptionObject(__FILE__,__LINE__);
    }

  // cache fixed image information
  m_FixedImageSpacing    = Superclass::m_FixedImage->GetSpacing();
  m_FixedImageOrigin     = Superclass::m_FixedImage->GetOrigin();

  // setup gradient calculator
  m_FixedImageGradientCalculator->SetInputImage( Superclass::m_FixedImage );
  m_MovingImageGradientCalculator->SetInputImage( Superclass::m_MovingImage  );
  
  // setup moving image interpolator
  m_MovingImageInterpolator->SetInputImage( Superclass::m_MovingImage );


  unsigned long numpix=1;
  for (int i=0; i<ImageDimension;i++) numpix*=Superclass::m_FixedImage->GetLargestPossibleRegion().GetSize()[i];
  m_MetricTotal=0.0;
  this->m_Energy=0.0;


  typedef itk::DiscreteGaussianImageFilter<BinaryImageType, BinaryImageType> dgf1;
//  typedef itk::DiscreteGaussianImageFilter<BinaryImageType, BinaryImageType> dgf;
  typedef itk::MeanImageFilter<BinaryImageType, BinaryImageType> dgf;
  typedef itk::MedianImageFilter<BinaryImageType, BinaryImageType> dgf2;
  
 
  // compute the normalizer
  m_Normalizer      = 0.0;
  for( unsigned int k = 0; k < ImageDimension; k++ )
    {
    m_Normalizer += m_FixedImageSpacing[k] * m_FixedImageSpacing[k];
    }
  m_Normalizer /= static_cast<double>( ImageDimension );
  
  typename FixedImageType::SpacingType spacing=this->GetFixedImage()->GetSpacing();

  bool makeimg=false;
  if ( m_Iteration==0 ) makeimg=true;
  else if (!finitediffimages[0] ) makeimg=true;
  else 
    {
      for (unsigned int dd=0; dd<ImageDimension; dd++)
	{
	  if ( finitediffimages[0]->GetLargestPossibleRegion().GetSize()[dd] != 
	    this->GetFixedImage()->GetLargestPossibleRegion().GetSize()[dd] ) makeimg=true;
	}
    }


  if (makeimg)
    {  
      finitediffimages[0]=this->MakeImage();
      finitediffimages[1]=this->MakeImage();
      finitediffimages[2]=this->MakeImage();
      finitediffimages[3]=this->MakeImage();
      finitediffimages[4]=this->MakeImage();
    }
  
  //float sig=15.;
  
  RadiusType r;
  for( int j = 0; j < ImageDimension; j++ )    r[j] = this->GetRadius()[j];

  typedef itk::ImageRegionIteratorWithIndex<MetricImageType> Iterator;
  Iterator tIter(this->GetFixedImage(),this->GetFixedImage()->GetLargestPossibleRegion() );

  typename FixedImageType::SizeType imagesize=this->GetFixedImage()->GetLargestPossibleRegion().GetSize();
 
  // compute local means
  //  typedef itk::ImageRegionIteratorWithIndex<MetricImageType> Iterator;
  Iterator outIter(this->finitediffimages[0],this->finitediffimages[0]->GetLargestPossibleRegion() );
  for( outIter.GoToBegin(); !outIter.IsAtEnd(); ++outIter )
    {


      bool takesample = true;  
      if (this->m_FixedImageMask) if (this->m_FixedImageMask->GetPixel( outIter.GetIndex() ) < 0.25 ) takesample=false;
	
      if (takesample)
       {

      NeighborhoodIterator<MetricImageType> 
	hoodIt( this->GetRadius() ,this->finitediffimages[0] , this->finitediffimages[0]->GetLargestPossibleRegion());
      IndexType oindex = outIter.GetIndex();
      hoodIt.SetLocation(oindex);
  
      double fixedMean=0;
      double movingMean=0;
     
      PointType mappedPoint;
      unsigned int indct;
      unsigned int hoodlen=hoodIt.Size();
      
//      unsigned int inct=0;
      double sumj=0,sumi=0;
      unsigned int cter=0;
      for(indct=0; indct<hoodlen; indct++)
	{	  
	  IndexType index=hoodIt.GetIndex(indct);
	  bool inimage=true;
	  for (unsigned int dd=0; dd<ImageDimension; dd++)
	    {
	      if ( index[dd] < 0 || index[dd] > static_cast<typename IndexType::IndexValueType>(imagesize[dd]-1) ) inimage=false;
	    }
	  if (inimage && this->m_FixedImageMask) if (this->m_FixedImageMask->GetPixel( index ) < 0.25 ) inimage=false;
	  if (inimage)
	    { 
	      sumj+=this->GetMovingImage()->GetPixel(index);
	      sumi+=this->GetFixedImage()->GetPixel(index);
	      cter++;
	    }
	}
      
      if (cter > 0) movingMean=sumj/(float)cter;
      if (cter > 0) fixedMean=sumi/(float)cter;
       
      float val = this->GetFixedImage()->GetPixel(oindex) - fixedMean;
      this->finitediffimages[0]->SetPixel( oindex, val );
      val = this->GetMovingImage()->GetPixel(oindex) - movingMean;
      this->finitediffimages[1]->SetPixel( oindex, val );
       }
    }
     

  for( outIter.GoToBegin(); !outIter.IsAtEnd(); ++outIter )
    {
      IndexType oindex = outIter.GetIndex();
      bool takesample = true;
      if (this->m_FixedImageMask) if (this->m_FixedImageMask->GetPixel( oindex  ) < 0.25 ) takesample=false;
      if (takesample)
       {
      NeighborhoodIterator<MetricImageType> 
	hoodIt( this->GetRadius() ,this->finitediffimages[0] , this->finitediffimages[0]->GetLargestPossibleRegion());
      hoodIt.SetLocation(oindex);
      double sff=0.0;
      double smm=0.0;
      double sfm=0.0;     
      PointType mappedPoint;
      unsigned int indct;
      unsigned int hoodlen=hoodIt.Size();
//      unsigned int inct=0;
      	  
      for(indct=0; indct<hoodlen; indct++)
	{
	  
	  IndexType index=hoodIt.GetIndex(indct);
	  bool inimage=true;
	  for (unsigned int dd=0; dd<ImageDimension; dd++)
	    {
	      if ( index[dd] < 0 || index[dd] > static_cast<typename IndexType::IndexValueType>(imagesize[dd]-1) ) inimage=false;
	    }
	  if (inimage && this->m_FixedImageMask) if (this->m_FixedImageMask->GetPixel( index ) < 0.25 ) inimage=false;
	  if (inimage)
	    {
	      double fixedValue =(double)this->finitediffimages[0]->GetPixel( index );
	      double movingValue=(double)this->finitediffimages[1]->GetPixel( index );
//	      double ofixedValue =(double)this->GetFixedImage()->GetPixel( index );
//	      double omovingValue=(double)this->GetMovingImage()->GetPixel( index );
	      
	      sff+=fixedValue*fixedValue;
	      smm+=movingValue*movingValue;
	      sfm+=fixedValue*movingValue;
	    }
	  
	}
      
      this->finitediffimages[2]->SetPixel( oindex, sfm );//A
      this->finitediffimages[3]->SetPixel( oindex, sff );//B
      this->finitediffimages[4]->SetPixel( oindex, smm );//C
      //         this->finitediffimages[5]->SetPixel( oindex , sumi);//B*C
      //    this->finitediffimages[6]->SetPixel( oindex , sumj);//B*C
       }
    }  
  
  //m_FixedImageGradientCalculator->SetInputImage(finitediffimages[0]); 
  
  m_MaxMag=0.0;
  m_MinMag=9.e9;
  m_AvgMag=0.0;  
  m_Iteration++;

}


/*
 * Compute the ncc metric everywhere
 */
template <class TFixedImage, class TMovingImage, class TDeformationField>
typename TDeformationField::PixelType
ProbabilisticRegistrationFunction<TFixedImage,TMovingImage,TDeformationField>
::ComputeMetricAtPairB(IndexType oindex, typename TDeformationField::PixelType vec)
{
  
  typename TDeformationField::PixelType deriv;
  deriv.Fill(0.0);
  double sff=0.0;
  double smm=0.0;
  double sfm=0.0;
//  double fixedValue;
//  double movingValue;
  sff=0.0;
  smm=0.0;
  sfm=0.0;
  PointType mappedPoint;
  CovariantVectorType gradI,gradJ;
  if (this->m_FixedImageMask) if (this->m_FixedImageMask->GetPixel( oindex ) < 0.25 ) 
    return deriv;
  
  sfm=finitediffimages[2]->GetPixel(oindex);
  sff=finitediffimages[3]->GetPixel(oindex);
  smm=finitediffimages[4]->GetPixel(oindex);
  
      IndexType index=oindex;//hoodIt.GetIndex(indct);
//      bool inimage=true;
      if (sff == 0.0) sff=1.0;
      if (smm == 0.0) smm=1.0;
      gradI = m_FixedImageGradientCalculator->EvaluateAtIndex( index ); 
      //	gradJ = m_MovingImageGradientCalculator->EvaluateAtIndex( index ); 
      
      float  Ji=finitediffimages[1]->GetPixel(index);
      float  Ii=finitediffimages[0]->GetPixel(index);
      
      m_TEMP=2.0*sfm/(sff*smm)*( Ji - sfm/sff*Ii );
      for (int qq=0; qq<ImageDimension; qq++) 
	{
	  deriv[qq]   -=2.0*sfm/(sff*smm)*( Ji - sfm/sff*Ii )*gradI[qq];
	  //	    derivinv[qq]-=2.0*sfm/(sff*smm)*( Ii - sfm/smm*Ji )*gradJ[qq];
	}
	
  if (sff*smm !=0.0) localProbabilistic = sfm*sfm / ( sff * smm );
  else if (sff == 0.0 && smm == 0) localProbabilistic = 1.0;
  else localProbabilistic = 1.0;
  if ( localProbabilistic*(-1.0) < this->m_RobustnessParameter) deriv.Fill(0);
  
//  if ( localProbabilistic*(-1.0) < this->m_RobustnessParameter) {
//  std::cout << " localC " << localProbabilistic << std::endl; }

  this->m_Energy-=localProbabilistic;
  return deriv;//localProbabilistic;

}


/*
 * Compute the ncc metric everywhere
 */
template <class TFixedImage, class TMovingImage, class TDeformationField>
typename TDeformationField::PixelType
ProbabilisticRegistrationFunction<TFixedImage,TMovingImage,TDeformationField>
::ComputeMetricAtPairC(IndexType oindex, typename TDeformationField::PixelType vec)
{
  
  typename TDeformationField::PixelType deriv;
  deriv.Fill(0.0);
  double sff=0.0;
  double smm=0.0;
  double sfm=0.0;
//  double fixedValue;
//  double movingValue;
  sff=0.0;
  smm=0.0;
  sfm=0.0;
  PointType mappedPoint;
  CovariantVectorType gradI,gradJ;
  if (this->m_FixedImageMask) if (this->m_FixedImageMask->GetPixel( oindex ) < 0.25 ) 
    return deriv;

  sfm=finitediffimages[2]->GetPixel(oindex);
  sff=finitediffimages[3]->GetPixel(oindex);
  smm=finitediffimages[4]->GetPixel(oindex);
  
      
  IndexType index=oindex;//hoodIt.GetIndex(indct);
  if (sff == 0.0) sff=1.0;
  if (smm == 0.0) smm=1.0;
  
  ///gradI = m_FixedImageGradientCalculator->EvaluateAtIndex( index ); 
  gradJ = m_MovingImageGradientCalculator->EvaluateAtIndex( index ); 

  float  Ji=finitediffimages[1]->GetPixel(index);
  float  Ii=finitediffimages[0]->GetPixel(index);


  for (int qq=0; qq<ImageDimension; qq++) 
    {
      //deriv[qq]   -=2.0*sfm/(sff*smm)*( Ji - sfm/sff*Ii )*gradI[qq];
      deriv[qq]-=2.0*sfm/(sff*smm)*( Ii - sfm/smm*Ji )*gradJ[qq];
    }


  if (sff*smm !=0.0) localProbabilistic = sfm*sfm / ( sff * smm );
  else if (sff == 0.0 && smm == 0) localProbabilistic = 1.0;
  else localProbabilistic = 1.0;
  if ( localProbabilistic*(-1.0) < this->m_RobustnessParameter) deriv.Fill(0);
    
  return deriv;//localProbabilistic;

}





} // end namespace itk

#endif
