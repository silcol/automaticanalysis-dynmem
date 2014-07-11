/*=========================================================================

  Program:   Insight Segmentation & Registration Toolkit
  Module:    $RCSfile: itkHistogramParzenWindowsListSampleFunction.h,v $
  Language:  C++
  Date:      $Date: $
  Version:   $Revision: $

  Copyright (c) Insight Software Consortium. All rights reserved.
  See ITKCopyright.txt or http://www.itk.org/HTML/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notices for more information.

=========================================================================*/
#ifndef __itkHistogramParzenWindowsListSampleFunction_h
#define __itkHistogramParzenWindowsListSampleFunction_h

#include "itkListSampleFunction.h"

#include "itkImage.h"

namespace itk {
namespace Statistics {

/** \class HistogramParzenWindowsListSampleFunction.h
 * \brief point set filter.
 */

template <class TListSample, class TOutput = double, class TCoordRep = double>
class ITK_EXPORT HistogramParzenWindowsListSampleFunction
: public ListSampleFunction<TListSample, TOutput, TCoordRep>
{
public:
  typedef HistogramParzenWindowsListSampleFunction         Self;
  typedef ListSampleFunction
    <TListSample, TOutput, TCoordRep>                      Superclass;
  typedef SmartPointer<Self>                               Pointer;
  typedef SmartPointer<const Self>                         ConstPointer;

  /** Method for creation through the object factory. */
  itkNewMacro( Self );

  /** Run-time type information (and related methods). */
  itkTypeMacro( HistogramParzenWindowsListSampleFunction, ListSampleFunction );

  typedef typename Superclass::InputListSampleType          InputListSampleType;
  typedef typename Superclass::InputMeasurementVectorType   InputMeasurementVectorType;
  typedef typename Superclass::InputMeasurementType         InputMeasurementType;

  /** List sample typedef support. */
  typedef TListSample                                       ListSampleType;

  /** Other typedef */
  typedef TOutput                                           RealType;
  typedef TOutput                                           OutputType;

  typedef Image<RealType, 1>                                HistogramImageType;


  /** Helper functions */

  itkSetMacro( Sigma, RealType );
  itkGetConstMacro( Sigma, RealType );

  itkSetMacro( NumberOfHistogramBins, unsigned int );
  itkGetConstMacro( NumberOfHistogramBins, unsigned int );

  virtual void SetInputListSample( const InputListSampleType * ptr );

  virtual TOutput Evaluate( const InputMeasurementVectorType& measurement ) const;

protected:
  HistogramParzenWindowsListSampleFunction();
  virtual ~HistogramParzenWindowsListSampleFunction();
  void PrintSelf( std::ostream& os, Indent indent ) const;

  void GenerateData();

private:
  //purposely not implemented
  HistogramParzenWindowsListSampleFunction( const Self& );
  void operator=( const Self& );

  unsigned int                                         m_NumberOfHistogramBins;
  RealType                                             m_Sigma;

  std::vector<typename HistogramImageType::Pointer>    m_HistogramImages;
};

} // end of namespace Statistics
} // end of namespace itk

#ifndef ITK_MANUAL_INSTANTIATION
#include "itkHistogramParzenWindowsListSampleFunction.txx"
#endif

#endif
