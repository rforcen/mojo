/*
    qhull_wrapper.c
*/

#include <libqhull_r/libqhull_r.h>
#include <libqhull_r/qhull_ra.h>

int qhull3d(int numPoints, double *points, size_t *n_equations,
            double **out_equations, size_t *n_simplices, int **out_simplices,
            size_t *n_hull_points, int **out_hull_points) {

  int dim = 3;

  qhT qh_ptr;
  qhT *qh = &qh_ptr;

  QHULL_LIB_CHECK
  qh_zero(qh, stderr);

  char flags[] =
      "qhull Qt"; // generate trigs, this is key for qhull.c3 post processing

  int exitcode =
      qh_new_qhull(qh, dim, numPoints, points, False, flags, NULL, stderr);

  // Check for errors

  if (!exitcode) {

    facetT *facet;
    vertexT *vertex;
    vertexT **vertexp;
    // Note: The macro expands to a for loop.
    // Ensure no space/semicolon between the macro and the block.
    // 1. Capture Equations and Simplices
    *n_equations = 0;
    *n_simplices = 0;
    *n_hull_points = 0;

    // count equations, simplices & hull points
    FORALLfacet_(qh->facet_list) {
      if (facet->visible || (qh->ONLYgood && !facet->good))
        continue;

      for (int k = 0; k < qh->hull_dim; k++)
        (*n_equations)++;
      (*n_equations)++;

      FOREACHvertex_(facet->vertices)(*n_simplices)++;
    }
    FORALLvertex_(qh->vertex_list)(*n_hull_points)++;

    // populate output cloning current vectors
    *out_equations = (double *)malloc((*n_equations) * sizeof(double));
    *out_simplices = (int *)malloc((*n_simplices) * sizeof(int));
    *out_hull_points = (int *)malloc((*n_hull_points) * sizeof(int));

    *n_equations = 0;
    *n_simplices = 0;
    *n_hull_points = 0;

    FORALLfacet_(qh->facet_list) {
      if (facet->visible || (qh->ONLYgood && !facet->good))
        continue;

      // Store Plane Equation [A, B, C, D] normal (a,b,c), distance (d)
      for (int k = 0; k < qh->hull_dim; k++)
        (*out_equations)[*n_equations + k] = facet->normal[k];
      (*out_equations)[*n_equations + qh->hull_dim] = facet->offset;
      *n_equations += qh->hull_dim + 1;

      // Store Simplex (Vertex Indices)
      FOREACHvertex_(facet->vertices) {
        (*out_simplices)[*n_simplices] = qh_pointid(qh, vertex->point);
        (*n_simplices)++;
      }
    }
    else { // error
      *out_equations = NULL;
      *out_simplices = NULL;
      *out_hull_points = NULL;
      *n_simplices = 0;
      *n_equations = 0;
      *n_hull_points = 0;
    }
  }

  // Standard cleanup for the reentrant library
  qh_freeqhull(qh, qh_ALL);
  int curlong, totlong;
  qh_memfreeshort(qh, &curlong, &totlong);

  return exitcode;
}

void qhull3d_free(double *equations, int *simplices, int *hull_points) {
  free(equations);
  free(simplices);
  free(hull_points);
}