import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Territory } from '../../territories/entities/territory.entity';

@Entity('qr_codes')
export class QrCode {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 9 })
  territory_id: string;

  @Column({ type: 'varchar', length: 200, nullable: true })
  venue_name: string | null;

  @Column({ type: 'varchar', length: 100, unique: true })
  code: string;

  @Column({ type: 'boolean', default: true })
  is_active: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @ManyToOne(() => Territory, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'territory_id' })
  territory: Territory;
}
