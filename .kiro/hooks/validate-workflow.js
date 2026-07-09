// validate-workflow.js - Hook para validar workflows de GitHub Actions
// Lee la entrada JSON desde stdin y verifica si el archivo being creado/modified es un workflow YAML

const fs = require('fs');
const path = require('path');
const process = require('process');

function validateWorkflow() {
  let stdinData = '';
  
  process.stdin.on('data', (chunk) => {
    stdinData += chunk;
  });

  process.stdin.on('end', () => {
    try {
      const context = JSON.parse(stdinData);
      const toolName = context.session?.lastToolUse?.toolName;
      const filePath = context.session?.lastToolUse?.arguments?.path || 
                       context.session?.lastToolUse?.arguments?.targetFile ||
                       context.session?.lastToolUse?.arguments?.path;

      // Solo validar si es una operación de escritura en workflows
      if (['fs_write', 'str_replace', 'fs_append'].includes(toolName) && filePath) {
        const normalizedPath = path.normalize(filePath);
        
        // Verificar si está en .github/workflows/
        if (normalizedPath.includes('.github/workflows') && normalizedPath.endsWith('.yml')) {
          // Leer el contenido del archivo
          let content = '';
          try {
            content = fs.readFileSync(filePath, 'utf8');
          } catch (e) {
            // Archivo no existe aún, no podemos validar
            console.log(JSON.stringify({ hookSpecificOutput: { permissionDecision: 'allow', permissionDecisionReason: 'Archivo nuevo o no accesible' } }));
            return;
          }

          // Verificar si hay un step con 'test' o 'Test'
          const hasTestStep = /- name:.*[Tt]est\s*$/m.test(content) || 
                              /run:\s*[nN]pm\s+[tT]est\s*$/m.test(content) ||
                              /run:\s*[nN]px\s+[jJ]est/m.test(content);

          if (!hasTestStep) {
            console.log(JSON.stringify({
              hookSpecificOutput: {
                permissionDecision: 'ask',
                permissionDecisionReason: 'El workflow no incluye un step de tests. Según los estándares DevOps, todos los pipelines deben incluir el step de test.'
              }
            }));
            process.exit(0);
          }
        }
      }

      // Permitir por defecto
      console.log(JSON.stringify({ hookSpecificOutput: { permissionDecision: 'allow', permissionDecisionReason: 'Validación exitosa o no aplica' } }));
      process.exit(0);

    } catch (error) {
      console.error('Error parsing input:', error.message);
      // En caso de error, permitir para no bloquear operaciones legítimas
      console.log(JSON.stringify({ hookSpecificOutput: { permissionDecision: 'allow', permissionDecisionReason: 'Error en validación, permitiendo por defecto' } }));
      process.exit(0);
    }
  });
}

validateWorkflow();