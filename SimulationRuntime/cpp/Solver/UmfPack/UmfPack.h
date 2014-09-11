#pragma once

#include <Core/System/IAlgLoop.h>                // Interface to AlgLoo
#include <Core/Solver/IAlgLoopSolver.h>        // Export function from dll
#include <Core/Solver/ILinSolverSettings.h>
#include <Core/Math/SparseMatrix.h>
#include "UmfPackSettings.h"
#include <iostream>


class UmfPack : public IAlgLoopSolver
{
public:
  UmfPack(IAlgLoop* algLoop,ILinSolverSettings* settings);
  virtual ~UmfPack();

    virtual void initialize();

    /// Solution of a (non-)linear system of equations
    virtual void solve();

    /// Returns the status of iteration
    virtual ITERATIONSTATUS getIterationStatus();
    virtual void stepCompleted(double time);

private:
    ITERATIONSTATUS _iterationStatus;
    ILinSolverSettings *_umfpackSettings;
    IAlgLoop *_algLoop;
    sparse_matrix * _jacs;
    double * _jacd;
    double * _rhs;
    double * _x;
    bool _firstuse;
};
