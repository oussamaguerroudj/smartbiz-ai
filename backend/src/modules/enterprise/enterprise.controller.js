const asyncHandler = require('../../utils/asyncHandler');
const service = require('./enterprise.service');

const getDashboard = asyncHandler(async (req, res) => {
  res.json({ data: await service.getDashboard(req.user.companyId) });
});

const listProjects = asyncHandler(async (req, res) => {
  res.json({ data: await service.listProjects(req.user.companyId, req.query.status) });
});

const createProject = asyncHandler(async (req, res) => {
  res.status(201).json({ data: await service.createProject(req.user.companyId, req.body) });
});

const updateProjectStatus = asyncHandler(async (req, res) => {
  res.json({ data: await service.updateProjectStatus(req.user.companyId, req.params.id, req.body.status) });
});

module.exports = { getDashboard, listProjects, createProject, updateProjectStatus };
