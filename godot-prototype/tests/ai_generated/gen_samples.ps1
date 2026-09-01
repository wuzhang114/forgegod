$ErrorActionPreference = 'Stop'

# Helper to append a sample
$script:items = New-Object System.Collections.ArrayList

function Add-Sample([string]$id, [string]$src) {
  $obj = [PSCustomObject]@{ id = $id; source = $src }
  [void]$script:items.Add($obj)
}

$src = @'
device FlameBlade {
  auth: item;
  budget: { entities: 2, steps: 8, cooldown: 8 };
  state: { };
  on attack {
    spawn_projectile(120, 0);
    apply_status(target, "burning", 60);
  }
}
'@
Add-Sample 'P01' $src

$src = @'
device EnergyShield {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 0 };
  state: { energy: 0; };
  on hurt {
    energy += hurt_damage;
  }
  on hit {
    if (energy >= 50) {
      damage(target, "physical", energy);
      energy = 0;
    }
  }
}
'@
Add-Sample 'P02' $src

$src = @'
device SoulEater {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 0 };
  state: { stacks: 0; bonus: 0; };
  on kill {
    if (stacks < 10) {
      stacks += 1;
      bonus += 2;
    }
  }
  on hit {
    if (bonus > 0) {
      damage(target, "physical", bonus);
    }
  }
}
'@
Add-Sample 'P03' $src

$src = @'
device SparkSummoner {
  auth: item;
  budget: { entities: 3, steps: 16, cooldown: 8 };
  state: { hits: 0; };
  on projectile_hit {
    if (has_status(target, "burning")) {
      hits += 1;
    } else {
      hits = 1;
      apply_status(target, "burning", 3);
    }
    if (hits >= 3) {
      spawn_sprite(3, 90, 30);
      set_mark(target);
      hits = 0;
    }
  }
}
'@
Add-Sample 'P04' $src

$src = @'
device DamageRetaliation {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { stored: 0; };
  on block {
    stored += blocked_damage;
  }
  on attack {
    if (stored > 0) {
      damage(target, "physical", stored);
      stored = 0;
    }
  }
}
'@
Add-Sample 'P05' $src

$src = @'
device CinderBlade {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 4 };
  state: { };
  on hit {
    apply_status(target, "burning", 60);
  }
  on kill {
    if (has_status(target, "burning")) {
      for e in enemies_in_range(40) {
        apply_status(e, "burning", 60);
        damage(e, "fire", 20);
      }
    }
  }
}
'@
Add-Sample 'P06' $src

$src = @'
device ExecuteBlade {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { };
  on hit {
    if (target_hp_ratio(target) < 0.3) {
      damage(target, "physical", 60);
    } else {
      damage(target, "physical", 10);
    }
  }
}
'@
Add-Sample 'P07' $src

$src = @'
device BlackHole {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 60 };
  state: { };
  on right_click {
    create_zone(50, 180, 60, 0);
  }
}
'@
Add-Sample 'P08' $src

$src = @'
device MoonlightEdge {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { };
  on hit {
    if (world_flag("night")) {
      damage(target, "physical", 25);
    }
  }
}
'@
Add-Sample 'P09' $src

$src = @'
device HuntersMark {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { };
  on hit {
    set_mark(target);
    if (mark_count(target) > 0) {
      damage(target, "physical", 12);
    }
  }
}
'@
Add-Sample 'P10' $src

$src = @'
device BloodPact {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { };
  on attack {
    damage_self(5);
    damage(target, "physical", 15);
  }
}
'@
Add-Sample 'P11' $src

$src = @'
device LeechFang {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 0 };
  state: { };
  on kill {
    heal_self(20);
  }
}
'@
Add-Sample 'P12' $src

$src = @'
device Frostbite {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 0 };
  state: { };
  on hit {
    apply_status(target, "slowed", 90);
  }
}
'@
Add-Sample 'P13' $src

$src = @'
device SpiritWard {
  auth: item;
  budget: { entities: 3, steps: 16, cooldown: 60 };
  state: { };
  on right_click {
    spawn_sprite(3, 240, 40);
  }
}
'@
Add-Sample 'P14' $src

$src = @'
device Riposte {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 0 };
  state: { };
  on block {
    damage(attacker, "physical", 20);
  }
}
'@
Add-Sample 'P15' $src

$src = @'
device EmberForge {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { heat: 0; };
  on hit {
    heat += 1;
    if (heat > 20) {
      heat = 0;
      apply_status(self, "disarmed", 60);
    } else if (heat >= 10) {
      damage(target, "fire", heat);
    }
  }
}
'@
Add-Sample 'P16' $src

$src = @'
device Shatter {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { };
  on hit {
    if (has_status(target, "stunned")) {
      damage(target, "physical", 30);
    }
  }
}
'@
Add-Sample 'P17' $src

$src = @'
device Burst {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 4 };
  state: { count: 0; };
  on hit {
    if (has_status(target, "bleeding")) {
      count += 1;
    } else {
      count = 1;
      apply_status(target, "bleeding", 3);
    }
    if (count >= 5) {
      damage(target, "physical", 80);
      count = 0;
    }
  }
}
'@
Add-Sample 'P18' $src

$src = @'
device Bastion {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 60 };
  state: { };
  on right_click {
    create_wall(8, 180);
  }
}
'@
Add-Sample 'P19' $src

$src = @'
device Rampart {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 20 };
  state: { };
  on right_click {
    dash(6);
  }
  on hit {
    knockback(target);
  }
}
'@
Add-Sample 'P20' $src

$src = @'
device Quake {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { energy: 0; };
  on kill {
    energy += 1;
    if (energy >= 3) {
      for e in enemies_in_range(80) {
        damage(e, "physical", 20);
      }
      energy = 0;
    }
  }
}
'@
Add-Sample 'P21' $src

$src = @'
device GlacialEdge {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 0 };
  state: { };
  on hit {
    apply_status(target, "frozen", 90);
  }
}
'@
Add-Sample 'P22' $src

$src = @'
device LeechShield {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 0 };
  state: { };
  on hurt {
    heal_self(6);
  }
}
'@
Add-Sample 'P23' $src

$src = @'
device Fireball {
  auth: item;
  budget: { entities: 2, steps: 16, cooldown: 30 };
  state: { };
  on right_click {
    spawn_projectile(90, 0);
  }
  on projectile_hit {
    for e in enemies_in_range(50) {
      damage(e, "fire", 25);
      apply_status(e, "burning", 60);
    }
  }
}
'@
Add-Sample 'P24' $src

$src = @'
device Truesilver {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { };
  on hit {
    damage(target, "physical", 10);
    damage(target, "physical", min(armor_value(target), 40));
  }
}
'@
Add-Sample 'P25' $src

$src = @'
device Vengeance {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { fury: 0; };
  on hurt {
    fury += 1;
  }
  on hit {
    if (fury > 0) {
      damage(target, "physical", fury);
    }
  }
}
'@
Add-Sample 'P26' $src

$src = @'
device TwinSlash {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 0 };
  state: { };
  on hit {
    if (rand_range(0, 100) < 30) {
      damage(target, "physical", 20);
    }
  }
}
'@
Add-Sample 'P27' $src

$src = @'
device Golem {
  auth: item;
  budget: { entities: 1, steps: 16, cooldown: 120 };
  state: { };
  on right_click {
    spawn_sprite(1, 300, 20);
  }
}
'@
Add-Sample 'P28' $src

$src = @'
device Stormcaller {
  auth: item;
  budget: { entities: 0, steps: 16, cooldown: 60 };
  state: { };
  on timer {
    if (count_entities() > 0) {
      damage(nearest_enemy(self), "lightning", 30);
    }
  }
}
'@
Add-Sample 'P29' $src

$src = @'
device SelfRepair {
  auth: item;
  budget: { entities: 0, steps: 8, cooldown: 0 };
  state: { };
  on hit {
    heal_weapon;
  }
}
'@
Add-Sample 'P30' $src

if ($script:items.Count -ne 30) {
  throw "Expected 30 samples, got $($script:items.Count)"
}

$json = $script:items | ConvertTo-Json -Depth 3
$out = 'D:\Game-Idea-Workshop\godot-prototype\tests\ai_generated\samples.json'
[System.IO.File]::WriteAllText($out, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "Wrote $out"
Write-Output "Byte length: $([System.IO.File]::ReadAllBytes($out).Length)"
