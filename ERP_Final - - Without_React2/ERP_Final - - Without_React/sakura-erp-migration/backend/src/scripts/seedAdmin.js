import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';

dotenv.config();

const prisma = new PrismaClient();

async function seedAdmin() {
  try {
    console.log('🌱 Seeding default admin user...');

    const adminEmail = 'sakurapersonal071@gmail.com';
    const adminPassword = 'Firoz112233@@';
    const adminName = 'Firoz Admin';

    // Check if admin already exists
    const existingAdmin = await prisma.user.findUnique({
      where: { email: adminEmail }
    });

    if (existingAdmin) {
      console.log('✅ Admin user already exists');
      
      // Update password if needed
      const passwordHash = await bcrypt.hash(adminPassword, 10);
      await prisma.user.update({
        where: { email: adminEmail },
        data: {
          passwordHash,
          status: 'active',
          role: 'admin',
          permissions: {
            accountsPayable: true,
            forecasting: true,
            warehouse: true,
            userManagement: true,
            reports: true,
            settings: true
          }
        }
      });
      console.log('✅ Admin password updated');
      return;
    }

    // Create admin user
    const passwordHash = await bcrypt.hash(adminPassword, 10);
    
    const admin = await prisma.user.create({
      data: {
        email: adminEmail,
        name: adminName,
        passwordHash,
        role: 'admin',
        status: 'active',
        emailVerified: true,
        permissions: {
          accountsPayable: true,
          forecasting: true,
          warehouse: true,
          userManagement: true,
          reports: true,
          settings: true
        },
        notes: 'Main Administrator - Default Admin Account'
      }
    });

    console.log('✅ Default admin user created successfully!');
    console.log(`   Email: ${adminEmail}`);
    console.log(`   Password: ${adminPassword}`);
    console.log(`   Name: ${adminName}`);
  } catch (error) {
    console.error('❌ Error seeding admin user:', error);
    throw error;
  } finally {
    await prisma.$disconnect();
  }
}

seedAdmin();

