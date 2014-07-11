/*=========================================================================

  Program:   Insight Segmentation & Registration Toolkit
  Module:    $RCSfile: itkBoxPlotQuantileListSampleFilter.h,v $
  Language:  C++
  Date:      $Date: $
  Version:   $Revision: $

  Copyright (c) Insight Software Consortium. All rights reserved.
  See ITKCopyright.txt or http://www.itk.org/HTML/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notices for more information.

=========================================================================*/
#ifndef __itkBoxPlotQuantileListSampleFilter_h
#define __itkBoxPlotQuantileListSampleFilter_h

#include "itkListSampleToListSampleFilter.h"

#include <vector>

namespace itk {
namespace Statistics {

/** \class BoxPlotQuantileListSampleFilter
 * \brief Base class of filters intended to generate scalar samples from
 * intensity samples.
 *
 */

template<class TScalarListSample>
class ITK_EXPORT BoxPlotQuantileListSampleFilter
: public ListSampleToListSampleFilter<TScalarListSample, TScalarListSample>
{
public:
  /**
   * Standard class typedefs.
   */
  typedef BoxPlotQuantileListSampleFilter                     Self;
  typedef ListSampleToListSampleFilter
    <TScalarListSample, TScalarListSample>                    Superclass;
  typedef SmartPointer<Self>                                  Pointer;
  typedef SmartPointer<const Self>                            ConstPointer;

  /**
   * Standard macros
   */
  itkTypeMacro( BoxPlotQuantileListSampleFilter,
    ListSampleToScalarListSampleFilter );

  /**
   * Method for creation through the object factory.
   */
  itkNewMacro( Self );

  /**
   * Conveneient typedefs
   */
  typedef double                                      RealType;
  typedef TScalarListSample                           ScalarListSampleType;
  typedef typename ScalarListSampleType
    ::MeasurementVectorType                           MeasurementVectorType;
  typedef typename ScalarListSampleType
    ::InstanceIdentifier                              InstanceIdentifierType;
  typedef std::vector<InstanceIdentifierType>         InstanceIdentifierContainerType;

  enum OutlierHandlingType { None, Trim, Winsorize };

  itkSetMacro( OutlierHandling, OutlierHandlingType );
  itkGetConstMacro( OutlierHandling, OutlierHandlingType );

  itkSetMacro( WhiskerScalingFactor, RealType );
  itkGetConstMacro( WhiskerScalingFactor, RealType );

  itkSetClampMacro( UpperPercentile, RealType, 0, 1 );
  itkGetConstMacro( UpperPercentile, RealType );

  itkSetClampMacro( LowerPercentile, RealType, 0, 1 );
  itkGetConstMacro( LowerPercentile, RealType );

  InstanceIdentifierContainerType GetOutlierInstanceIdentifiers()
    {
    return this->m_OutlierInstanceIdentifiers;
    }

//   itkGetConstMacro( Outliers, InstanceIdentifierContainerType );

protected:
  BoxPlotQuantileListSampleFilter();
  virtual ~BoxPlotQuantileListSampleFilter();

  void PrintSelf( std::ostream& os, Indent indent ) const;

  virtual void GenerateData();

private:
  BoxPlotQuantileListSampleFilter( const Self& ); //purposely not implemented
  void operator=( const Self& ); //purposely not implemented

  InstanceIdentifierType FindMaximumNonOutlierDeviationValue( RealType, RealType );
  bool IsMeasurementAnOutlier( RealType, RealType, RealType, unsigned long );

  OutlierHandlingType                                 m_OutlierHandling;
  InstanceIdentifierContainerType                     m_OutlierInstanceIdentifiers;
  RealType                                            m_WhiskerScalingFactor;
  RealType                                            m_LowerPercentile;
  RealType                                            m_UpperPercentile;


}; // end of class

} // end of namespace Statistics
} // end of namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkBoxPlotQuantileListSampleFilter.txx"
#endif

#endif
