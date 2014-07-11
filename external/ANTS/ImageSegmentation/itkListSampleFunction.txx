/*=========================================================================

  Program:   Insight Segmentation & Registration Toolkit
  Module:    $RCSfile: itkListSampleFunction.txx,v $
  Language:  C++
  Date:      $Date: 2008/10/18 00:20:04 $
  Version:   $Revision: 1.1.1.1 $

  Copyright (c) Insight Software Consortium. All rights reserved.
  See ITKCopyright.txt or http://www.itk.org/HTML/Copyright.htm for details.

     This software is distributed WITHOUT ANY WARRANTY; without even
     the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
     PURPOSE.  See the above copyright notices for more information.

=========================================================================*/
#ifndef __itkListSampleFunction_txx
#define __itkListSampleFunction_txx

#include "itkListSampleFunction.h"

namespace itk {
namespace Statistics {

/**
 * Constructor
 */
template <class TInputListSample, class TOutput, class TCoordRep>
ListSampleFunction<TInputListSample, TOutput, TCoordRep>
::ListSampleFunction()
{
  this->m_ListSample = NULL;
}


/**
 * Standard "PrintSelf" method
 */
template <class TInputListSample, class TOutput, class TCoordRep>
void
ListSampleFunction<TInputListSample, TOutput, TCoordRep>
::PrintSelf(
  std::ostream& os,
  Indent indent) const
{
  os << indent << "InputListSample: " << m_ListSample.GetPointer() << std::endl;
}

template <class TInputListSample, class TOutput, class TCoordRep>
void
ListSampleFunction<TInputListSample, TOutput, TCoordRep>
::SetWeights( WeightArrayType* array )
{
  this->m_Weights = *array;
  this->Modified();
}

template <class TInputListSample, class TOutput, class TCoordRep>
typename ListSampleFunction<TInputListSample, TOutput, TCoordRep>::WeightArrayType*
ListSampleFunction<TInputListSample, TOutput, TCoordRep>
::GetWeights()
{
  return &this->m_Weights;
}

/**
 * Initialize by setting the input point set
 */
template <class TInputListSample, class TOutput, class TCoordRep>
void
ListSampleFunction<TInputListSample, TOutput, TCoordRep>
::SetInputListSample(
  const InputListSampleType * ptr )
{
  // set the input image
  m_ListSample = ptr;
}

} // end of namespace Statistics
} // end of namespace itk

#endif

