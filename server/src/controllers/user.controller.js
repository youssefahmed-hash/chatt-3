import { Op } from 'sequelize';
import { User } from '../models/User.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { ApiError } from '../utils/ApiError.js';

// GET /api/users?search=...
export const listUsers = asyncHandler(async (req, res) => {
  const { search } = req.query;

  const where = { id: { [Op.ne]: req.user.id } };
  if (search) {
    where[Op.or] = [
      { name: { [Op.iLike]: `%${search}%` } },
      { email: { [Op.iLike]: `%${search}%` } },
    ];
  }

  const users = await User.findAll({
    where,
    order: [['name', 'ASC']],
    limit: 50,
  });
  res.json({ users });
});


export const updateProfile = asyncHandler(async (req, res) => {
  const { name, bio } = req.body;

  const user = req.user;

  if (name !== undefined) {
    if (!name.trim()) {
      throw new ApiError(400, 'Name cannot be empty');
    }

    user.name = name.trim();
  }

  if (bio !== undefined) {
    user.bio = bio.trim();
  }

  await user.save();

  res.json({
    message: 'Profile updated successfully',
    user,
  });
});

// GET /api/users/:id
export const getUser = asyncHandler(async (req, res) => {
  const user = await User.findByPk(req.params.id);
  if (!user) {
    return res.status(404).json({ error: 'User not found' });
  }
  res.json({ user });
});

export const updateAvatar = asyncHandler(async (req, res) => {

  if (!req.file) {
    throw new ApiError(400, 'Avatar image required');
  }


  const user = req.user;

  user.avatarUrl = `/uploads/avatars/${req.file.filename}`;

  await user.save();


  res.json({
    message: 'Avatar updated successfully',
    user,
  });

});

export const getProfile = asyncHandler(async (req, res) => {
  res.json({
    user: req.user,
  });
});
