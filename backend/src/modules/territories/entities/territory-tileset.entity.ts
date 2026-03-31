import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('territory_tilesets')
export class TerritoryTileset {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'varchar', length: 100, unique: true })
  key: string;

  @Column({ type: 'varchar', length: 50 })
  format: string;

  @Column({ type: 'varchar', length: 255 })
  source_url: string;

  @Column({ type: 'varchar', length: 120 })
  attribution: string;

  @Column({ type: 'int', default: 0 })
  minzoom: number;

  @Column({ type: 'int', default: 14 })
  maxzoom: number;

  @Column({ type: 'numeric', precision: 10, scale: 6, nullable: true })
  bounds_west: number | null;

  @Column({ type: 'numeric', precision: 10, scale: 6, nullable: true })
  bounds_south: number | null;

  @Column({ type: 'numeric', precision: 10, scale: 6, nullable: true })
  bounds_east: number | null;

  @Column({ type: 'numeric', precision: 10, scale: 6, nullable: true })
  bounds_north: number | null;

  @Column({ type: 'numeric', precision: 10, scale: 6, nullable: true })
  center_lng: number | null;

  @Column({ type: 'numeric', precision: 10, scale: 6, nullable: true })
  center_lat: number | null;

  @Column({ type: 'int', nullable: true })
  center_zoom: number | null;

  @Column({ type: 'varchar', length: 100, nullable: true })
  layer_name: string | null;

  @Column({ type: 'boolean', default: true })
  is_active: boolean;

  @CreateDateColumn({ type: 'timestamptz' })
  created_at: Date;

  @UpdateDateColumn({ type: 'timestamptz' })
  updated_at: Date;
}
