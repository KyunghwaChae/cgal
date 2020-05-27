// Copyright (c) 2015  Geometry Factory
// All rights reserved.
//
// This file is part of CGAL (www.cgal.org)
//
// $URL$
// $Id$
// SPDX-License-Identifier: LGPL-3.0-or-later OR LicenseRef-Commercial
//
// Author(s) : Lutz Kettner
//             Andreas Fabri
//             Maxime Gimeno

#ifndef CGAL_IO_OBJ_H
#define CGAL_IO_OBJ_H

#include <CGAL/IO/OBJ/File_writer_wavefront.h>
#include <CGAL/IO/Generic_writer.h>

#include <boost/range/value_type.hpp>

#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace CGAL {

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
/// Read

namespace IO {
namespace internal {

template <typename PointRange, typename PolygonRange, typename VertexNormalOutputIterator>
bool read_OBJ(std::istream& is,
              PointRange& points,
              PolygonRange& faces,
              VertexNormalOutputIterator vn_out,
              bool verbose = true)
{
  typedef typename boost::range_value<PointRange>::type                               Point;
  typedef typename CGAL::Kernel_traits<Point>::Kernel                                 Kernel;
  typedef typename Kernel::Vector_3                                                   Normal;

  int mini(1),
      maxi(-1);
  Point p;
  std::string line;

  while(getline(is, line))
  {
    if(line[0] == 'v' && line[1] == ' ')
    {
      std::istringstream iss(line.substr(1));
      if(!(iss >> p) || !iss)
      {
        if(verbose)
          std::cerr<<"error while reading OBJ vertex. "<<std::endl;
        return false;
      }

      points.push_back(p);
    }
    else if(line[0] == 'f' && line[1] == ' ') // @fixme range checks
    {
      std::istringstream iss(line.substr(1));
      int i;
      faces.push_back(std::vector<std::size_t>());
      while(iss >> i)
      {
        if(i < 1)
        {
          faces.back().push_back(points.size()+i); // negative indices are relative references
          if(i < mini)
            mini = i;
        }
        else
        {
          faces.back().push_back(i-1);
          if(i-1 > maxi)
            maxi = i-1;
        }
       // iss.ignore(256, ' ');
      }

      if(iss.bad())
        return false;
    }
    else if(line[0] == 'v' &&  line[1] == 'n' && line[2] == ' ')
    {
      std::istringstream iss(line);
      std::string dummy;
      if(!(iss >> dummy))
      {
        if(verbose)
          std::cerr<<"error while reading OBJ vertex normal. "<<std::endl;
        return false;
      }

      double nx, ny, nz; // @fixme double?
      if(iss >> nx >> ny >> nz)
        *vn_out++ = Normal(nx, ny, nz); // @fixme check that every vertex has a normal?
      else
        return false;
    }
    else
    {
      //std::cerr << "ERROR : Cannnot read line beginning with " << line[0] << std::endl;
     continue;
    }
  }
  if(maxi==-1 && mini == 1)
  {
    if(verbose)
      std::cerr<<"No face detected."<<std::endl;
    return false;
  }
  if(maxi > static_cast<int>(points.size()) || mini < -static_cast<int>(points.size()))
  {
    if(verbose)
      std::cerr << "a face index is invalid " << std::endl;
    return false;
  }
  bool res = is.bad();
  return !res;
}

} // namespace internal
} // namespace IO


template <typename PointRange, typename PolygonRange, typename CGAL_BGL_NP_TEMPLATE_PARAMETERS>
bool read_OBJ(std::istream& is,
              PointRange& points,
              PolygonRange& faces,
              const CGAL_BGL_NP_CLASS& np,
              bool verbose = true)
{
  using parameters::choose_parameter;
  using parameters::get_parameter;

  return IO::internal::read_OBJ(is, points, faces,
                                choose_parameter(get_parameter(np, internal_np::vertex_normal_output_iterator),
                                                 CGAL::Emptyset_iterator()),
                                verbose);
}

template <typename PointRange, typename PolygonRange, typename CGAL_BGL_NP_TEMPLATE_PARAMETERS>
bool read_OBJ(const char* fname,
              PointRange& points,
              PolygonRange& polygons,
              const CGAL_BGL_NP_CLASS& np,
              bool verbose = true)
{
  std::ifstream in(fname);
  return read_OBJ(in, points, polygons, np, verbose);
}

template <typename PointRange, typename PolygonRange, typename CGAL_BGL_NP_TEMPLATE_PARAMETERS>
bool read_OBJ(const std::string& fname, PointRange& points, PolygonRange& polygons, const CGAL_BGL_NP_CLASS& np,
              bool verbose = true)
{
  return read_OBJ(fname.c_str(), points, polygons, np, verbose);
}

//! \ingroup ObjIoFuncs
//!
/// reads the content of `is` into `points` and `faces`, using the `OBJ` format.
///
/// \tparam PointRange a `RandomAccessContainer` of `Point_3`
/// \tparam PolygonRange a `RandomAccessContainer` of `RandomAccessContainer` of `std::size_t`
///
/// \see \ref IOStreamOBJ
template <typename PointRange, typename PolygonRange>
bool read_OBJ(std::istream& is, PointRange& points, PolygonRange& faces)
{
  return read_OBJ(is, points, faces, parameters::all_default());
}

//! \ingroup ObjIoFuncs
//!
/// reads the content of the file `fname` into `points` and `faces`, using the `OBJ` format.
///
/// \tparam PointRange a `RandomAccessContainer` of `Point_3`
/// \tparam PolygonRange a `RandomAccessContainer` of `RandomAccessContainer` of `std::size_t`
///
/// \see \ref IOStreamOBJ
template <typename PointRange, typename PolygonRange>
bool read_OBJ(const char* fname, PointRange& points, PolygonRange& faces)
{
  return read_OBJ(fname, points, faces, parameters::all_default());
}

template <typename PointRange, typename PolygonRange>
bool read_OBJ(const std::string& fname, PointRange& points, PolygonRange& polygons)
{
  return read_OBJ(fname, points, polygons, parameters::all_default());
}

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
/// Write

template <typename PointRange,
          typename PolygonRange,
          typename CGAL_BGL_NP_TEMPLATE_PARAMETERS>
bool write_OBJ(std::ostream& os,
               const PointRange& points,
               const PolygonRange& polygons,
               const CGAL_BGL_NP_CLASS&)
{
  Generic_writer<std::ostream, File_writer_wavefront> writer(os);
  return writer(points, polygons);
}

/*!
 * \ingroup ObjIoFuncs
 *
 * writes the content of `points` and `polygons` in `os`, in the OBJ format.
 *
 * \see \ref IOStreamOBJ
 */
template <typename PointRange,
          typename PolygonRange>
bool write_OBJ(std::ostream& os,
               const PointRange& points,
               const PolygonRange& polygons)
{
  return write_OBJ(os, points, polygons, parameters::all_default());
}

template <typename PointRange,
          typename PolygonRange,
          typename CGAL_BGL_NP_TEMPLATE_PARAMETERS>
bool write_OBJ(const char* fname,
               const PointRange& points,
               const PolygonRange& polygons,
               const CGAL_BGL_NP_CLASS& np)
{
  std::ofstream out(fname);
  return write_OBJ(out, points, polygons, np);
}

/*!
 * \ingroup ObjIoFuncs
 *
 * writes the content of `points` and `polygons` in a file named `fname`, in the OBJ format.
 *
 * \see \ref IOStreamOBJ
 */
template <typename PointRange,
          typename PolygonRange>
bool write_OBJ(const char* fname,
               const PointRange& points,
               const PolygonRange& polygons)
{
  return write_OBJ(fname, points, polygons);
}

template <typename PointRange,
          typename PolygonRange,
          typename CGAL_BGL_NP_TEMPLATE_PARAMETERS>
bool write_OBJ(const std::string& fname,
               const PointRange& points,
               const PolygonRange& polygons,
               const CGAL_BGL_NP_CLASS& np)
{
  return write_OBJ(fname.c_str(), points, polygons,np);
}

template <typename PointRange, typename PolygonRange>
bool write_OBJ(const std::string& fname, const PointRange& points, const PolygonRange& polygons)
{
  return write_OBJ(fname, points, polygons, parameters::all_default());
}

} // namespace CGAL

#endif // CGAL_IO_OBJ_H
