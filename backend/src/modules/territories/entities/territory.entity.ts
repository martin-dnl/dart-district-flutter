import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Club } from '../../clubs/entities/club.entity';

@Entity('territories')
export class Territory {
  @PrimaryColumn({ type: 'varchar', length: 9 })
  code_iris: string;

  @Column({ type: 'varchar', length: 255 })
  name: string;

  @Column({ type: 'varchar', length: 5, nullable: true })
  insee_com: string | null;

  @Column({ type: 'varchar', length: 150, nullable: true })
  nom_com: string | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  nom_iris: string | null;

  @Column({ type: 'varchar', length: 30, nullable: true })
  iris_type: string | null;

  @Column({ type: 'varchar', length: 3, nullable: true })
  dep_code: string | null;

  @Column({ type: 'varchar', length: 2, nullable: true })
  dep_name: string | null;

  @Column({ type: 'varchar', length: 3, nullable: true })
  region_code: string | null;

  @Column({ type: 'varchar', length: 120, nullable: true })
  region_name: string | null;

  @Column({ type: 'int', nullable: true })
  population: number | null;

  @Column({ type: 'numeric', precision: 10, scale: 7 })
  centroid_lat: number;

  @Column({ type: 'numeric', precision: 10, scale: 7 })
  centroid_lng: number;

  @Column({ type: 'numeric', precision: 12, scale: 2, nullable: true })
  area_m2: number | null;

  @Column({
    type: 'enum',
    enum: ['available', 'locked', 'alert', 'conquered', 'conflict'],
    default: 'available',
  })
  status: string;

  @Column({ type: 'uuid', nullable: true })
  owner_club_id: string | null;

  @Column({ type: 'timestamptz', nullable: true })
  conquered_at: Date | null;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;

  @ManyToOne(() => Club, { onDelete: 'SET NULL' })
  @JoinColumn({ name: 'owner_club_id' })
  owner_club: Club;
}
