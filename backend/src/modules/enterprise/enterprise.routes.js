const express = require('express');
const controller = require('./enterprise.controller');
const { validateCreateProject, validateProjectStatus } = require('./enterprise.validators');
const { authMiddleware } = require('../../middlewares/auth.middleware');
const { requireBusinessType } = require('../../middlewares/businessType.middleware');

/**
 * Enterprise / Company vertical (Ch. 19). Clients, Employees,
 * Suppliers, Invoices, Payments and Expenses all stay on their CORE
 * endpoints (`/customers`, `/employees`, `/suppliers`, `/invoices`,
 * `/credit`, `/expenses`)  -  this router only adds what doesn't exist
 * anywhere else: the dashboard aggregate and Projects.
 */
const router = express.Router();

router.use(authMiddleware);
router.use(
  requireBusinessType(
    'company',
    'workshop',
    'beauty_salon',
    'barbershop',
    'gym',
    'hotel',
    'medical_laboratory',
    'car_repair',
    'electronics_store',
    'bakery',
    'law_office',
    'accounting_office',
    'real_estate_agency',
    'education_center',
    'other',
  ),
);

router.get('/dashboard', controller.getDashboard);

router.get('/projects', controller.listProjects);
router.post('/projects', validateCreateProject, controller.createProject);
router.patch('/projects/:id/status', validateProjectStatus, controller.updateProjectStatus);

module.exports = router;
